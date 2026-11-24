/**
 * Cole este código no Apps Script (substitua o anterior).
 *
 * DONO ÚNICO DO PROJETO (obrigatório):
 *   Conta: administrativo@gssolucoestec.com.br
 *   - Pasta das OS no Drive: proprietário = administrativo@
 *   - Projeto Apps Script: criado/implantado como administrativo@
 *   - Planilha GS Campo: compartilhada com administrativo@ (editor)
 *   Não implante este script com Gmail pessoal: os arquivos e a cota
 *   ficam na conta errada e o limite do Drive volta a estourar.
 *   Transferência em lote: transferOsDriveToAdministrativo
 *   (ver google/DONO_ADMINISTRATIVO.md).
 *
 * Implantar → Gerenciar implantações → lápis → Nova versão
 *   Executar como: eu  (= administrativo@)
 *   Quem tem acesso: Qualquer pessoa
 *
 * O Chrome não consegue ler JSON direto (CORS). O app web chama GET
 * com ?callback=... e POST com text/plain (o corpo é JSON mesmo assim).
 * doPost precisa ler esse JSON; senão o envio do RDO vira action=status
 * e o app avisa que enviou sem mandar o e-mail.
 * Implante Nova versão na implantação que o app já usa (lápis), não crie outra URL.
 *
 * Folhas compartilhadas entre todos os funcionários cadastrados:
 *   usuarios, ordens, clientes
 *
 * E-mail do RDO: o navegador não anexa arquivo no Gmail. O script envia
 * com MailApp para todos os e-mails administrativos da planilha, mais
 * administrativo@ e amanda@gssolucoestec.com.br.
 * Arquivos das OS (RDO, fotos, anexos, certificados, RH): action=saveosfolder
 * grava na pasta DEFAULT_FILES_FOLDER_ID_ (ou GS_FILES_FOLDER_ID) do Drive
 * do escritório (administrativo@gssolucoestec.com.br).
 * Assinatura do cliente: action=signpage&token=...
 * Depois de colar este código, rode authorizeMail, authorizeStaffDocs,
 * authorizeClientPayloads e authorizeDriveFiles uma vez cada (Aceitar
 * permissões) e publique Nova versão no mesmo lápis / mesma URL.
 */

const DEV_TOKEN = 'gs-dev-gate-v1';
/** Planilha oficial GS Campo (não criar outra). */
const KNOWN_SHEET_ID = '1vUj-oGqqeSZ-wmoMH1vX9on7AYHaPSG8bz3ml2i645o';
const MAIN_PASS_HASHES = {
  gssolucoes:
    'b06b393ba66d6dd7f7f9ecabc154f12e24e6be8413689f902e1e1c158c13201b',
  cleber: 'ad7d93d193cd354bad0bb1442129124cf7ffe65568517e7db215dc03eba6342a',
  vinicius: '35d3069de28a6c4824e5c84114be99b0880009290feef92d70b9ae08871d4323',
};
const USER_HEADERS = [
  'email',
  'nome',
  'login',
  'senha_hash',
  'telefone',
  'papel',
  'status',
  'ativo',
  'criado_em',
  'funcao',
  'cargo',
  'calibracao',
  'permissoes',
  'jornada',
];

var CALLBACK_ = '';

/**
 * Versões antigas do app sobrescreviam OS e certificados com cache velho.
 * Até a 252, salvar a OS regravava o 1º preset de cada ilha do cliente.
 * 255–256 tratavam a OS enxuta da nuvem como completa e regravavam slots.
 */
const MIN_WRITE_BUILD = 257;
const GATED_WRITE_ACTIONS_ = [
  'saveos', 'os.save', 'putos', 'deleteos', 'os.delete',
  'savecalib', 'calib.save', 'savecalibration',
  'deletecalib', 'calib.delete', 'deletecalibration',
  'saveclient', 'deleteclient',
];
const LOCKED_WRITE_ACTIONS_ = GATED_WRITE_ACTIONS_.concat([
  'client.save', 'client.delete', 'saverdo', 'rdo.save', 'putrdo',
]);

/** Dois aparelhos salvando a mesma OS ao mesmo tempo: um apagava o do outro. */
function withWriteLock_(p, fn) {
  const action = String(p.action || p.cmd || p.op || '').toLowerCase();
  if (LOCKED_WRITE_ACTIONS_.indexOf(action) < 0) return fn();
  const lock = LockService.getScriptLock();
  if (!lock.tryLock(25000)) {
    CALLBACK_ = String(p.callback || '')
      .replace(/[^A-Za-z0-9_$.]/g, '')
      .slice(0, 80);
    return json_({
      ok: false,
      error: 'Servidor ocupado salvando outro registro. Tente de novo em instantes.',
    });
  }
  try {
    return fn();
  } finally {
    lock.releaseLock();
  }
}

function doGet(e) {
  const p = (e && e.parameter) || {};
  try {
    return withWriteLock_(p, function () {
      return handle_(p);
    });
  } catch (error) {
    // Sem isso o Google devolve página HTML e o app acha que pediu login.
    CALLBACK_ = String(p.callback || '')
      .replace(/[^A-Za-z0-9_$.]/g, '')
      .slice(0, 80);
    return json_({ ok: false, error: String((error && error.message) || error) });
  }
}

function doPost(e) {
  try {
    var p = (e && e.parameter) || {};
    if (e && e.postData && e.postData.contents) {
      const raw = String(e.postData.contents || '').trim();
      if (raw.charAt(0) === '{' || raw.charAt(0) === '[') {
        const body = JSON.parse(raw);
        if (body && typeof body === 'object' && !Array.isArray(body)) {
          p = Object.assign({}, p, body);
        }
      } else {
        const type = String((e.postData.type || '')).toLowerCase();
        if (type.indexOf('json') >= 0) {
          p = Object.assign({}, p, JSON.parse(e.postData.contents));
        }
      }
    }
    return withWriteLock_(p, function () {
      return handle_(p);
    });
  } catch (error) {
    return json_({ ok: false, error: String((error && error.message) || error) });
  }
}

function handle_(p) {
  CALLBACK_ = String(p.callback || '')
    .replace(/[^A-Za-z0-9_$.]/g, '')
    .slice(0, 80);
  const action = String(p.action || p.cmd || p.op || 'status').toLowerCase();
  // Pasta das OS no Google Drive não depende da planilha.
  // onedrivestatus: apps antigos ainda pedem com esse nome.
  if (action === 'drivestatus' || action === 'onedrivestatus') {
    if (!hasToken_(p)) return json_({ ok: false, error: 'Sem permissão' });
    return driveStatus_(p);
  }
  if (action === 'saveosfolder' || action === 'osfolder.save') {
    if (!hasToken_(p)) return json_({ ok: false, error: 'Sem permissão' });
    return saveOsFolder_(p);
  }
  if (action === 'checkosfolder' || action === 'osfolder.check') {
    if (!hasToken_(p)) return json_({ ok: false, error: 'Sem permissão' });
    return checkOsFolder_(p);
  }
  if (action === 'osfolderstatus' || action === 'osfolder.status') {
    if (!hasToken_(p)) return json_({ ok: false, error: 'Sem permissão' });
    return osFolderStatus_(p);
  }
  if (
    action === 'listosdrive' ||
    action === 'osdrive.list' ||
    action === 'listdirveos'
  ) {
    if (!hasToken_(p)) return json_({ ok: false, error: 'Sem permissão' });
    return listOsDrive_(p);
  }
  const ss = spreadsheet_();
  if (GATED_WRITE_ACTIONS_.indexOf(action) >= 0 && Number(p.appBuild || 0) < MIN_WRITE_BUILD) {
    return json_({
      ok: false,
      updateRequired: true,
      error:
        'App desatualizado: feche e abra o GS Campo (ou Ctrl+Shift+R) para atualizar antes de salvar.',
    });
  }
  if (action === 'status') {
    return json_({ ok: true, cleberBlocked: isBlocked_(ss) });
  }
  if (action === 'certpublic' || action === 'cert.public') {
    return certPublic_(ss, p);
  }
  if (action === 'sheetinfo') {
    if (!hasToken_(p)) return json_({ ok: false, error: 'Sem permissão' });
    return sheetInfo_(ss);
  }
  if (action === 'block') {
    if (!hasToken_(p)) return json_({ ok: false, error: 'Sem permissão' });
    setBlocked_(ss, yes_(p.value));
    return json_({ ok: true, cleberBlocked: isBlocked_(ss) });
  }
  if (action === 'signup') {
    return signup_(ss, p);
  }
  if (action === 'login') {
    return login_(ss, p);
  }
  if (action === 'users') {
    if (!hasToken_(p)) return json_({ ok: false, error: 'Sem permissão' });
    return json_({ ok: true, users: publicUsers_(ss) });
  }
  if (action === 'decide') {
    if (!hasToken_(p)) return json_({ ok: false, error: 'Sem permissão' });
    return decide_(ss, p);
  }
  if (action === 'setpapel') {
    if (!hasToken_(p)) return json_({ ok: false, error: 'Sem permissão' });
    return setPapel_(ss, p);
  }
  if (action === 'setfuncao' || action === 'funcao') {
    if (!hasToken_(p)) return json_({ ok: false, error: 'Sem permissão' });
    return setFuncao_(ss, p);
  }
  if (action === 'setcargo' || action === 'cargo') {
    if (!hasToken_(p)) return json_({ ok: false, error: 'Sem permissão' });
    return setCargo_(ss, p);
  }
  if (action === 'setcalibracao' || action === 'calibracao') {
    if (!hasToken_(p)) return json_({ ok: false, error: 'Sem permissão' });
    return setCalibracao_(ss, p);
  }
  if (action === 'setpermissoes' || action === 'permissoes' || action === 'setpermissions') {
    if (!hasToken_(p)) return json_({ ok: false, error: 'Sem permissão' });
    return setPermissoes_(ss, p);
  }
  if (action === 'setjornada' || action === 'jornada' || action === 'setschedules') {
    if (!hasToken_(p)) return json_({ ok: false, error: 'Sem permissão' });
    return setJornada_(ss, p);
  }
  if (action === 'setativo') {
    if (!hasToken_(p)) return json_({ ok: false, error: 'Sem permissão' });
    return setAtivo_(ss, p);
  }
  if (action === 'setperfil' || action === 'perfil') {
    return setPerfil_(ss, p);
  }
  if (action === 'setsenha' || action === 'senha') {
    return setSenha_(ss, p);
  }
  if (action === 'saveos' || action === 'os.save' || action === 'putos') {
    return saveOs_(ss, p);
  }
  if (action === 'saverdo' || action === 'rdo.save' || action === 'putrdo') {
    return saveRdo_(ss, p);
  }
  if (action === 'getos' || action === 'os.get') {
    return getOs_(ss, p);
  }
  if (action === 'listos' || action === 'os.list') {
    return listOs_(ss);
  }
  if (action === 'deleteos' || action === 'os.delete') {
    return deleteOs_(ss, p);
  }
  if (action === 'saveclient' || action === 'client.save') {
    return saveClient_(ss, p);
  }
  if (action === 'getclient' || action === 'client.get') {
    return getClient_(ss, p);
  }
  if (action === 'listclients' || action === 'clients') {
    return listClients_(ss);
  }
  if (action === 'deleteclient' || action === 'client.delete') {
    return deleteClient_(ss, p);
  }
  if (action === 'savestandard' || action === 'standard.save') {
    return saveStandard_(ss, p);
  }
  if (action === 'liststandards' || action === 'standards') {
    return listStandards_(ss);
  }
  if (action === 'deletestandard' || action === 'standard.delete') {
    return deleteStandard_(ss, p);
  }
  if (action === 'savefluid' || action === 'fluid.save') {
    return saveFluid_(ss, p);
  }
  if (action === 'listfluids' || action === 'fluids') {
    return listFluids_(ss);
  }
  if (action === 'deletefluid' || action === 'fluid.delete') {
    return deleteFluid_(ss, p);
  }
  if (action === 'savecalib' || action === 'calib.save' || action === 'savecalibration') {
    return saveCalib_(ss, p);
  }
  if (action === 'listcalib' || action === 'calib.list' || action === 'calibrations') {
    return listCalibs_(ss);
  }
  if (action === 'getcalib' || action === 'calib.get') {
    return getCalib_(ss, p);
  }
  if (action === 'deletecalib' || action === 'calib.delete' || action === 'deletecalibration') {
    return deleteCalib_(ss, p);
  }
  if (action === 'snapshot' || action === 'sync') {
    return snapshot_(ss, p);
  }
  if (action === 'sendmail' || action === 'mail.send') {
    if (!hasToken_(p)) return json_({ ok: false, error: 'Sem permissão' });
    return sendMail_(ss, p);
  }
  if (action === 'savestaffdoc' || action === 'staffdoc.save') {
    if (!hasToken_(p)) return json_({ ok: false, error: 'Sem permissão' });
    return saveStaffDoc_(ss, p);
  }
  if (action === 'liststaffdocs' || action === 'staffdocs') {
    return listStaffDocs_(ss, p);
  }
  if (action === 'getstaffdoc' || action === 'staffdoc.get') {
    return getStaffDoc_(ss, p);
  }
  if (action === 'signstaffdoc' || action === 'staffdoc.sign') {
    return signStaffDoc_(ss, p);
  }
  if (action === 'deletestaffdoc' || action === 'staffdoc.delete') {
    if (!hasToken_(p)) return json_({ ok: false, error: 'Sem permissão' });
    return deleteStaffDoc_(ss, p);
  }
  if (action === 'mailstatus' || action === 'mail.status') {
    if (!hasToken_(p)) return json_({ ok: false, error: 'Sem permissão' });
    return mailStatus_(p);
  }
  if (action === 'signrequest' || action === 'pedirassinatura') {
    if (!hasToken_(p)) return json_({ ok: false, error: 'Sem permissão' });
    return signRequest_(ss, p);
  }
  if (action === 'signpage' || action === 'assinar') {
    return signPage_(ss, p);
  }
  if (action === 'clientsign' || action === 'signrdo') {
    return clientSign_(ss, p);
  }
  return json_({ ok: false, error: 'Ação inválida' });
}

function hasToken_(p) {
  return String(p.token || '') === DEV_TOKEN;
}

/**
 * Sempre a planilha oficial. Nunca cria/usa outra: se a conta que implantou
 * não tiver acesso, falha com erro (o app não sincroniza, mas nada se perde).
 */
function spreadsheet_() {
  const sheetId = officialSheetId_();
  var known;
  try {
    known = SpreadsheetApp.openById(sheetId);
  } catch (error) {
    throw new Error(
      'Sem acesso à planilha oficial do GS Campo (' +
        sheetId +
        '). Implante o script com a conta do escritório. Detalhe: ' +
        error,
    );
  }
  ensureSheets_(known);
  const props = PropertiesService.getScriptProperties();
  if (props.getProperty('SHEET_ID') !== sheetId) {
    props.setProperty('SHEET_ID', sheetId);
  }
  return known;
}

/** GS_SHEET_ID (gravada por migrarParaEstaConta) vence a planilha antiga. */
function officialSheetId_() {
  const moved = PropertiesService.getScriptProperties().getProperty(
    'GS_SHEET_ID',
  );
  return moved ? String(moved).trim() : KNOWN_SHEET_ID;
}

/**
 * Rode UMA vez no editor (▶️) com a conta NOVA, no script da CÓPIA da planilha.
 * 1) Liga o script a esta cópia (GS_SHEET_ID).
 * 2) Copia para esta conta os JSON grandes e documentos do RH que ainda estão
 *    no Drive da conta antiga (as pastas "GS Campo - …" precisam estar
 *    compartilhadas com esta conta) e troca os IDs nas células.
 * Se parar por tempo, rode de novo: continua de onde parou.
 */
function migrarParaEstaConta() {
  const props = PropertiesService.getScriptProperties();
  var ss = null;
  try {
    ss = SpreadsheetApp.getActiveSpreadsheet();
  } catch (error) {}
  if (!ss && props.getProperty('GS_SHEET_ID')) {
    ss = SpreadsheetApp.openById(props.getProperty('GS_SHEET_ID'));
  }
  if (!ss) {
    throw new Error(
      'Abra este script pela cópia da planilha (Extensões → Apps Script) ' +
        'ou grave a propriedade GS_SHEET_ID com o ID da cópia.',
    );
  }
  props.setProperty('GS_SHEET_ID', ss.getId());
  props.setProperty('SHEET_ID', ss.getId());

  const me = String(Session.getEffectiveUser().getEmail() || '').toLowerCase();
  const started = Date.now();
  const folderCache = {};
  const copied = {};
  var copies = 0;
  var missing = 0;
  var timedOut = false;

  function folder(name) {
    if (folderCache[name]) return folderCache[name];
    const found = DriveApp.getFoldersByName(name);
    var picked = null;
    while (found.hasNext()) {
      const f = found.next();
      const owner = f.getOwner();
      if (owner && String(owner.getEmail()).toLowerCase() === me) {
        picked = f;
        break;
      }
    }
    folderCache[name] = picked || DriveApp.createFolder(name);
    return folderCache[name];
  }

  function ownCopy(fileId, folderName) {
    const id = String(fileId || '').trim();
    if (!id) return id;
    if (copied[id]) return copied[id];
    var file;
    try {
      file = DriveApp.getFileById(id);
    } catch (error) {
      missing++;
      copied[id] = id;
      return id;
    }
    const owner = file.getOwner();
    if (owner && String(owner.getEmail()).toLowerCase() === me) {
      copied[id] = id;
      return id;
    }
    const copy = file.makeCopy(file.getName(), folder(folderName));
    copies++;
    copied[id] = copy.getId();
    return copied[id];
  }

  const payloadFolders = {
    ordens: 'GS Campo - Ordens JSON',
    clientes: 'GS Campo - Clientes JSON',
    calibracoes: 'GS Campo - Calibracoes JSON',
  };

  const sheets = ss.getSheets();
  outer: for (var s = 0; s < sheets.length; s++) {
    const sheet = sheets[s];
    const tab = sheet.getName();
    const values = sheet.getDataRange().getValues();
    for (var r = 1; r < values.length; r++) {
      for (var c = 0; c < values[r].length; c++) {
        if (Date.now() - started > 5 * 60 * 1000) {
          timedOut = true;
          break outer;
        }
        const raw = values[r][c];
        if (tab === 'staff_docs' && (c === 8 || c === 9)) {
          const oldId = String(raw || '').trim();
          if (!oldId) continue;
          const newId = ownCopy(oldId, 'GS Campo - RH Documentos');
          if (newId !== oldId) sheet.getRange(r + 1, c + 1).setValue(newId);
          continue;
        }
        if (typeof raw !== 'string' || raw.indexOf('"_fileId"') < 0) continue;
        const parsed = parseOrderCell_(raw);
        if (!parsed || !parsed._fileId) continue;
        const oldFileId = String(parsed._fileId);
        const newFileId = ownCopy(
          oldFileId,
          payloadFolders[tab] || 'GS Campo - Outros JSON',
        );
        if (newFileId !== oldFileId) {
          parsed._fileId = newFileId;
          sheet.getRange(r + 1, c + 1).setValue(JSON.stringify(parsed));
        }
      }
    }
  }
  SpreadsheetApp.flush();
  return (
    (timedOut ? 'PAROU POR TEMPO — rode de novo para continuar. ' : 'Concluído. ') +
    'Planilha: ' +
    ss.getName() +
    ' (' +
    ss.getId() +
    '). Arquivos copiados agora: ' +
    copies +
    '. Não encontrados: ' +
    missing +
    '. Conta: ' +
    me
  );
}

function sheetInfo_(ss) {
  function rows(name) {
    const sh = ss.getSheetByName(name);
    return sh ? Math.max(0, sh.getLastRow() - 1) : -1;
  }
  var who = '';
  try {
    who = Session.getEffectiveUser().getEmail();
  } catch (error) {}
  return json_({
    ok: true,
    sheetId: ss.getId(),
    sheetName: ss.getName(),
    official: ss.getId() === officialSheetId_(),
    runAs: who,
    counts: {
      usuarios: rows('usuarios'),
      ordens: rows('ordens'),
      clientes: rows('clientes'),
      calibracoes: rows('calibracoes'),
      calib_excluidos: rows('calib_excluidos'),
    },
  });
}

/**
 * Rode uma vez no editor (▶️) com a conta do escritório.
 * Amarras SHEET_ID à planilha oficial e cria abas que faltarem.
 * Depois: Implantar → lápis → Nova versão (MESMA URL — não crie outra).
 */
function bindGsCampoSheet() {
  const props = PropertiesService.getScriptProperties();
  const sheetId = officialSheetId_();
  props.setProperty('SHEET_ID', sheetId);
  const ss = SpreadsheetApp.openById(sheetId);
  ensureSheets_(ss);
  ensureCalibsSheet_(ss);
  return (
    'Planilha ligada: ' +
    ss.getName() +
    ' (' +
    sheetId +
    '). Publique Nova versão no mesmo lápis.'
  );
}

function ensureSheets_(ss) {
  var users = ss.getSheetByName('usuarios');
  if (!users) {
    users = ss.insertSheet('usuarios');
    users.appendRow(USER_HEADERS);
    seedUsers_(users);
  } else {
    migrateUsers_(users);
  }
  ensureUserColumns_(users);
  ensureMainPasswords_(users);
  ensureKnownUsers_(users);
  repairAccounts_(users);
  hideStubTechnicians_(users);
  migrateAndreLogin_(users);
  var control = ss.getSheetByName('controle');
  if (!control) {
    control = ss.insertSheet('controle');
    control.appendRow(['chave', 'valor']);
    control.appendRow(['cleber_bloqueado', 'nao']);
  }
  ensureOsSheet_(ss);
  ensureClientSheet_(ss);
  ensureStaffDocsSheet_(ss);
  ensureCalibsSheet_(ss);
  ensureFluidsSheet_(ss);
}

function seedUsers_(sheet) {
  const now = new Date();
  sheet.appendRow([
    'administrativo@gssolucoestec.com.br',
    'GS Soluções',
    'gssolucoes',
    MAIN_PASS_HASHES.gssolucoes,
    '',
    'admin',
    'aprovado',
    'sim',
    now,
  ]);
  sheet.appendRow([
    'cleber@gssolucoestec.com.br',
    'Cleber Guimarães',
    'cleber',
    MAIN_PASS_HASHES.cleber,
    '',
    'ambos',
    'aprovado',
    'sim',
    now,
  ]);
  sheet.appendRow([
    'viniciusmagalhaes2y@gmail.com',
    'Vinicius Magalhães',
    'vinicius',
    MAIN_PASS_HASHES.vinicius,
    '',
    'dev',
    'aprovado',
    'sim',
    now,
  ]);
}

function ensureUserColumns_(sheet) {
  var lastCol = Math.max(sheet.getLastColumn(), 1);
  const headers = sheet
    .getRange(1, 1, 1, lastCol)
    .getValues()[0]
    .map(function (h) {
      return String(h).trim().toLowerCase();
    });
  USER_HEADERS.forEach(function (name) {
    if (headers.indexOf(name) < 0) {
      lastCol += 1;
      sheet.getRange(1, lastCol).setValue(name);
      headers.push(name);
    }
  });
}

function migrateUsers_(sheet) {
  const lastCol = Math.max(sheet.getLastColumn(), 1);
  const headers = sheet
    .getRange(1, 1, 1, lastCol)
    .getValues()[0]
    .map(function (h) {
      return String(h).trim().toLowerCase();
    });
  if (headers.indexOf('login') >= 0 && headers.indexOf('status') >= 0) {
    return;
  }
  const data = sheet.getDataRange().getValues();
  const rows = [];
  for (var i = 1; i < data.length; i++) {
    const email = String(data[i][0] || '').trim();
    if (!email) continue;
    const nome = String(data[i][1] || '');
    const papel = String(data[i][2] || 'tecnico');
    const ativo = String(data[i][3] || 'sim');
    rows.push([
      email,
      nome,
      loginFromEmail_(email),
      '',
      '',
      papel,
      'aprovado',
      ativo,
      '',
    ]);
  }
  sheet.clear();
  sheet.appendRow(USER_HEADERS);
  if (rows.length === 0) {
    seedUsers_(sheet);
    return;
  }
  rows.forEach(function (row) {
    sheet.appendRow(row);
  });
  ensureMainPasswords_(sheet);
}

function ensureMainPasswords_(sheet) {
  const map = colMap_(sheet);
  if (map.senha_hash < 0 || map.login < 0) return;
  const users = readUsers_(sheet);
  users.forEach(function (user) {
    if (user.passHash) return;
    const hash = MAIN_PASS_HASHES[user.login];
    if (!hash) return;
    sheet.getRange(user.row, map.senha_hash + 1).setValue(hash);
  });
}

function ensureKnownUsers_(sheet) {
  const seeds = [
    {
      email: 'administrativo@gssolucoestec.com.br',
      name: 'GS Soluções',
      login: 'gssolucoes',
      passHash: MAIN_PASS_HASHES.gssolucoes,
      role: 'admin',
    },
    {
      email: 'cleber@gssolucoestec.com.br',
      name: 'Cleber Guimarães',
      login: 'cleber',
      passHash: MAIN_PASS_HASHES.cleber,
      role: 'ambos',
    },
    {
      email: 'viniciusmagalhaes2y@gmail.com',
      name: 'Vinicius Magalhães',
      login: 'vinicius',
      passHash: MAIN_PASS_HASHES.vinicius,
      role: 'dev',
    },
  ];
  var users = readUsers_(sheet);
  seeds.forEach(function (seed) {
    var existing = findUser_(users, seed.email);
    if (!existing) {
      sheet.appendRow([
        seed.email,
        seed.name,
        seed.login,
        seed.passHash,
        '',
        seed.role,
        'aprovado',
        'sim',
        new Date(),
      ]);
      users = readUsers_(sheet);
    }
  });
}

function loginFromEmail_(email) {
  const at = String(email).indexOf('@');
  if (at <= 0) return String(email).toLowerCase();
  return String(email)
    .slice(0, at)
    .toLowerCase();
}

function colMap_(sheet) {
  const headers = sheet
    .getRange(1, 1, 1, Math.max(sheet.getLastColumn(), 1))
    .getValues()[0]
    .map(function (h) {
      return String(h).trim().toLowerCase();
    });
  const map = {};
  USER_HEADERS.forEach(function (name) {
    map[name] = headers.indexOf(name);
  });
  return map;
}

function cell_(row, map, name) {
  const i = map[name];
  if (i < 0 || i == null) return '';
  return row[i];
}

function readUsers_(sheet) {
  const values = sheet.getDataRange().getValues();
  if (values.length < 2) return [];
  const map = colMap_(sheet);
  const users = [];
  for (var i = 1; i < values.length; i++) {
    const row = values[i];
    const email = String(cell_(row, map, 'email') || '')
      .trim()
      .toLowerCase();
    if (!email) continue;
    users.push({
      row: i + 1,
      email: email,
      name: String(cell_(row, map, 'nome') || '').trim(),
      login: String(cell_(row, map, 'login') || '')
        .trim()
        .toLowerCase(),
      passHash: String(cell_(row, map, 'senha_hash') || '').trim(),
      phone: String(cell_(row, map, 'telefone') || '').trim(),
      role: normalizeRole_(cell_(row, map, 'papel')),
      status: String(cell_(row, map, 'status') || 'aprovado')
        .trim()
        .toLowerCase(),
      active: yes_(cell_(row, map, 'ativo')),
      funcao: normalizeFuncao_(cell_(row, map, 'funcao')),
      cargo: String(cell_(row, map, 'cargo') || '').trim().slice(0, 80),
      calibracao: normalizeCalibracao_(cell_(row, map, 'calibracao')),
      permissoes: String(cell_(row, map, 'permissoes') || '').trim() || 'geral',
      jornada: String(cell_(row, map, 'jornada') || '').trim(),
    });
  }
  return users;
}

function publicUsers_(ss) {
  const sheet = ss.getSheetByName('usuarios');
  return readUsers_(sheet).map(publicUser_);
}

function publicUser_(user) {
  return {
    email: user.email,
    name: user.name,
    login: user.login,
    phone: user.phone,
    role: user.role,
    status: user.status,
    active: user.active,
    funcao: user.funcao || '',
    cargo: user.cargo || '',
    calibracao: user.calibracao || 'nao',
    permissoes: user.permissoes || 'geral',
    jornada: user.jornada || '',
  };
}

function normalizeJornada_(raw) {
  const value = String(raw || '').trim();
  if (!value) return '';
  try {
    const parsed = JSON.parse(value);
    if (!Array.isArray(parsed)) return '';
    return JSON.stringify(parsed).slice(0, 50000);
  } catch (err) {
    return '';
  }
}

function setJornada_(ss, p) {
  ensureSheets_(ss);
  const sheet = ss.getSheetByName('usuarios');
  ensureUserColumns_(sheet);
  const user = findUser_(readUsers_(sheet), p.email || p.login);
  if (!user) return json_({ ok: false, error: 'Usuário não encontrado.' });
  const map = colMap_(sheet);
  if (map.jornada < 0) {
    return json_({
      ok: false,
      error: 'Atualize o script para gravar a carga horária (jornada).',
    });
  }
  sheet
    .getRange(user.row, map.jornada + 1)
    .setValue(normalizeJornada_(p.jornada || p.value || ''));
  return json_({ ok: true, users: publicUsers_(ss) });
}

function normalizeFuncao_(raw) {
  const value = String(raw || '').trim();
  if (!value) return '';
  const folded = String(value || '')
    .toLowerCase()
    .replace(/[áàâãä]/g, 'a')
    .replace(/[éèêë]/g, 'e')
    .replace(/[íìîï]/g, 'i')
    .replace(/[óòôõö]/g, 'o')
    .replace(/[úùûü]/g, 'u')
    .replace(/ç/g, 'c');
  if (folded === 'responsavel tecnico' || folded === 'rt') {
    return 'Responsável técnico';
  }
  if (folded === 'suporte tecnico' || folded === 'suporte') {
    return 'Suporte Técnico';
  }
  return value.slice(0, 80);
}

function normalizeRole_(raw) {
  const value = String(raw || '')
    .trim()
    .toLowerCase();
  if (value === 'admin' || value === 'adm' || value === 'administrativo') {
    return 'admin';
  }
  if (value === 'dev' || value === 'desenvolvedor') return 'dev';
  if (value === 'ambos' || value === 'tecnico e administrativo') return 'ambos';
  return 'tecnico';
}

function findUser_(users, raw) {
  const value = String(raw || '')
    .trim()
    .toLowerCase();
  if (!value) return null;
  if (
    value === 'andre' ||
    value === 'andré' ||
    value === 'nascimento' ||
    value === 'andrenascimento'
  ) {
    for (var i = 0; i < users.length; i++) {
      if (String(users[i].login) === 'nascimento' && users[i].active) {
        return users[i];
      }
    }
    for (var j = 0; j < users.length; j++) {
      if (String(users[j].login) === 'nascimento') return users[j];
    }
  }
  for (var i = 0; i < users.length; i++) {
    const user = users[i];
    if (user.email === value || user.login === value) return user;
  }
  if (isPrincipalLookup_(value)) {
    for (var i = 0; i < users.length; i++) {
      if (users[i].email === 'administrativo@gssolucoestec.com.br') {
        return users[i];
      }
    }
    for (var i = 0; i < users.length; i++) {
      if (users[i].login === 'gssolucoes') return users[i];
    }
  }
  if (isCleberLookup_(value)) {
    for (var i = 0; i < users.length; i++) {
      if (users[i].email === 'cleber@gssolucoestec.com.br') return users[i];
    }
    for (var i = 0; i < users.length; i++) {
      if (users[i].login === 'cleber') return users[i];
    }
  }
  for (var i = 0; i < users.length; i++) {
    const user = users[i];
    const local = user.email.split('@')[0];
    if (
      local === value &&
      !isPrincipalLookup_(value) &&
      !isCleberLookup_(value)
    ) {
      return user;
    }
    if (value === 'vinicius' && local.indexOf('vinicius') === 0) return user;
  }
  return null;
}

function isPrincipalLookup_(value) {
  const raw = String(value || '')
    .trim()
    .toLowerCase();
  return (
    raw === 'gssolucoes' ||
    raw === 'gs' ||
    raw === 'gs soluções' ||
    raw === 'gs solucoes' ||
    raw === 'administrativo' ||
    raw === 'administrativo@gssolucoestec.com.br'
  );
}

function isCleberLookup_(value) {
  const raw = String(value || '')
    .trim()
    .toLowerCase();
  if (!raw) return false;
  const user = raw.split('@')[0];
  const compact = user.replace(/[\s._-]+/g, '');
  return (
    raw === 'cleber' ||
    raw === 'cleber@gssolucoestec.com.br' ||
    raw === 'cleber guimarães' ||
    raw === 'cleber guimaraes' ||
    raw.indexOf('cleber ') === 0 ||
    raw.indexOf('cleber_') === 0 ||
    raw.indexOf('cleber-') === 0 ||
    raw.indexOf('cleber.') === 0 ||
    raw.indexOf('cleber@') === 0 ||
    user === 'cleber' ||
    compact === 'cleber' ||
    compact.indexOf('cleberguimar') === 0
  );
}

function repairAccounts_(sheet) {
  const map = colMap_(sheet);
  var users = readUsers_(sheet);
  var principal = null;
  var cleber = null;
  for (var i = 0; i < users.length; i++) {
    if (users[i].email === 'administrativo@gssolucoestec.com.br') {
      principal = users[i];
    }
    if (users[i].email === 'cleber@gssolucoestec.com.br') {
      cleber = users[i];
    }
  }
  if (principal) {
    if (
      map.login >= 0 &&
      (!principal.login ||
        principal.login === 'cleber' ||
        principal.login === 'administrativo')
    ) {
      sheet.getRange(principal.row, map.login + 1).setValue('gssolucoes');
    }
    if (
      map.nome >= 0 &&
      (!principal.name || principal.name === 'Cleber Guimarães')
    ) {
      sheet.getRange(principal.row, map.nome + 1).setValue('GS Soluções');
    }
    if (map.papel >= 0) {
      sheet.getRange(principal.row, map.papel + 1).setValue('admin');
    }
    if (map.status >= 0) {
      sheet.getRange(principal.row, map.status + 1).setValue('aprovado');
    }
    if (map.ativo >= 0) {
      sheet.getRange(principal.row, map.ativo + 1).setValue('sim');
    }
    if (map.senha_hash >= 0 && !principal.passHash) {
      sheet
        .getRange(principal.row, map.senha_hash + 1)
        .setValue(MAIN_PASS_HASHES.gssolucoes);
    }
  }
  if (!cleber) {
    sheet.appendRow([
      'cleber@gssolucoestec.com.br',
      'Cleber Guimarães',
      'cleber',
      MAIN_PASS_HASHES.cleber,
      '',
      'ambos',
      'aprovado',
      'sim',
      new Date(),
    ]);
  } else {
    if (
      map.login >= 0 &&
      (!cleber.login ||
        cleber.login.indexOf('cleber ') === 0 ||
        cleber.login.indexOf('dup-') === 0)
    ) {
      sheet.getRange(cleber.row, map.login + 1).setValue('cleber');
    }
    if (map.nome >= 0 && !cleber.name) {
      sheet.getRange(cleber.row, map.nome + 1).setValue('Cleber Guimarães');
    }
    if (map.papel >= 0) {
      sheet.getRange(cleber.row, map.papel + 1).setValue('ambos');
    }
    if (map.status >= 0) {
      sheet.getRange(cleber.row, map.status + 1).setValue('aprovado');
    }
    if (map.ativo >= 0) {
      sheet.getRange(cleber.row, map.ativo + 1).setValue('sim');
    }
    if (map.senha_hash >= 0 && !cleber.passHash) {
      sheet
        .getRange(cleber.row, map.senha_hash + 1)
        .setValue(MAIN_PASS_HASHES.cleber);
    }
  }
  users = readUsers_(sheet);
  users.forEach(function (user) {
    if (user.email === 'administrativo@gssolucoestec.com.br') return;
    if (user.email === 'cleber@gssolucoestec.com.br') return;
    if (
      user.login === 'cleber' ||
      user.login === 'gssolucoes' ||
      user.login === 'administrativo'
    ) {
      if (map.login >= 0) {
        sheet.getRange(user.row, map.login + 1).setValue('dup-' + user.row);
      }
    }
  });
}

function hideStubTechnicians_(sheet) {
  const map = colMap_(sheet);
  if (map.ativo < 0) return;
  const users = readUsers_(sheet);
  var hasFelps = false;
  var hasRealAndre = false;
  for (var i = 0; i < users.length; i++) {
    const user = users[i];
    if (!user.active || user.status !== 'aprovado') continue;
    if (String(user.login) === 'felps1255') hasFelps = true;
    if (
      String(user.login) === 'nascimento' ||
      (String(user.login) === 'andre' &&
        String(user.email) !== 'andre@gssolucoestec.com.br')
    ) {
      hasRealAndre = true;
    }
  }
  for (var j = 0; j < users.length; j++) {
    const user = users[j];
    if (!user.active) continue;
    if (hasFelps && String(user.login) === 'felipe') {
      sheet.getRange(user.row, map.ativo + 1).setValue('nao');
    }
    if (
      hasRealAndre &&
      String(user.email) === 'andre@gssolucoestec.com.br' &&
      String(user.login) !== 'nascimento'
    ) {
      sheet.getRange(user.row, map.ativo + 1).setValue('nao');
    }
  }
}

function migrateAndreLogin_(sheet) {
  const map = colMap_(sheet);
  if (map.login < 0) return;
  const users = readUsers_(sheet);
  var hasNascimento = false;
  for (var i = 0; i < users.length; i++) {
    if (String(users[i].login) === 'nascimento') hasNascimento = true;
  }
  if (hasNascimento) return;
  for (var j = 0; j < users.length; j++) {
    const user = users[j];
    if (!user.active || user.status !== 'aprovado') continue;
    const login = String(user.login || '');
    const name = String(user.name || '').toLowerCase();
    const email = String(user.email || '').toLowerCase();
    if (email === 'andre@gssolucoestec.com.br') continue;
    if (
      login === 'andre' ||
      login === 'andrenascimento' ||
      name.indexOf('nascimento') >= 0
    ) {
      sheet.getRange(user.row, map.login + 1).setValue('nascimento');
      return;
    }
  }
}

function signup_(ss, p) {
  ensureSheets_(ss);
  const sheet = ss.getSheetByName('usuarios');
  const login = String(p.login || '')
    .trim()
    .toLowerCase();
  const email = String(p.email || '')
    .trim()
    .toLowerCase();
  const name = String(p.name || p.nome || '').trim();
  const phone = String(p.phone || p.telefone || '').trim();
  const passHash = String(p.passHash || p.senha_hash || '').trim();
  const role = normalizeRole_(p.role || p.papel);
  if (!login) return json_({ ok: false, error: 'Informe o usuário.' });
  if (!email || email.indexOf('@') < 0) {
    return json_({ ok: false, error: 'Informe um e-mail válido.' });
  }
  if (!phone) return json_({ ok: false, error: 'Informe o telefone.' });
  if (!passHash) return json_({ ok: false, error: 'Informe a senha.' });
  if (role === 'dev') {
    return json_({ ok: false, error: 'Escolha Administrativo ou Técnico.' });
  }
  const reserved = reservedSignupError_(login, email);
  if (reserved) {
    return json_({ ok: false, error: reserved });
  }
  const users = readUsers_(sheet);
  if (findUser_(users, login) || findUser_(users, email)) {
    return json_({ ok: false, error: 'Este usuário ou e-mail já existe.' });
  }
  sheet.appendRow([
    email,
    name || login,
    login,
    passHash,
    phone,
    role === 'admin' ? 'admin' : 'tecnico',
    'pendente',
    'nao',
    new Date(),
  ]);
  return json_({
    ok: true,
    pending: true,
    message:
      'Conta enviada. Aguarde a liberação do acesso.',
  });
}

function isReservedIdentity_(login, email) {
  return !!reservedSignupError_(login, email);
}

function reservedSignupError_(login, email) {
  const user = String(login || '')
    .trim()
    .toLowerCase();
  const mail = String(email || '')
    .trim()
    .toLowerCase();
  const mailUser = mail.split('@')[0];
  if (isCleberLookup_(mail) || mailUser === 'cleber') {
    return 'Este e-mail é do Cleber. Use outro e-mail para cadastrar.';
  }
  if (isPrincipalLookup_(mail)) {
    return 'Este e-mail é do acesso principal da GS Soluções. Use outro e-mail.';
  }
  if (mail === 'viniciusmagalhaes2y@gmail.com') {
    return 'Este e-mail é do desenvolvedor. Use outro e-mail para cadastrar.';
  }
  if (isCleberLookup_(user) || user.split(/[\s._-]+/)[0] === 'cleber') {
    return 'O login cleber já existe. Use outro usuário.';
  }
  if (isPrincipalLookup_(user) || user.split(/[\s._-]+/)[0] === 'gssolucoes') {
    return 'Este usuário é do acesso principal. Use outro login.';
  }
  if (user === 'vinicius' || user.split(/[\s._-]+/)[0] === 'vinicius') {
    return 'Este usuário é do desenvolvedor. Use outro login.';
  }
  return '';
}

function collectPassHashes_(p) {
  const out = [];
  function add(value) {
    String(value || '')
      .split(',')
      .forEach(function (item) {
        const hash = String(item || '').trim();
        if (hash && out.indexOf(hash) < 0) out.push(hash);
      });
  }
  add(p.passHash);
  add(p.senha_hash);
  add(p.passHashes);
  return out;
}

function passHashMatches_(user, p) {
  if (!user.passHash) return true;
  const hashes = collectPassHashes_(p);
  const accepted = [user.passHash];
  if (MAIN_PASS_HASHES[user.login]) accepted.push(MAIN_PASS_HASHES[user.login]);
  if (user.email === 'administrativo@gssolucoestec.com.br') {
    accepted.push(MAIN_PASS_HASHES.gssolucoes);
  }
  if (user.email === 'cleber@gssolucoestec.com.br') {
    accepted.push(MAIN_PASS_HASHES.cleber);
  }
  if (user.email === 'viniciusmagalhaes2y@gmail.com') {
    accepted.push(MAIN_PASS_HASHES.vinicius);
  }
  for (var i = 0; i < hashes.length; i++) {
    if (accepted.indexOf(hashes[i]) >= 0) return true;
  }
  return false;
}

function login_(ss, p) {
  ensureSheets_(ss);
  const sheet = ss.getSheetByName('usuarios');
  const login = String(p.login || p.email || '')
    .trim()
    .toLowerCase();
  const user = findUser_(readUsers_(sheet), login);
  if (!user) return json_({ ok: false, error: 'Usuário não encontrado.' });
  if (!passHashMatches_(user, p)) {
    return json_({ ok: false, error: 'Senha incorreta.', wrongPassword: true });
  }
  if (user.status === 'pendente') {
    return json_({
      ok: false,
      pending: true,
      error: 'Conta aguardando aprovação do escritório.',
    });
  }
  if (user.status === 'recusado') {
    return json_({ ok: false, error: 'Conta não autorizada.' });
  }
  if (!user.active) {
    return json_({ ok: false, error: 'Este acesso está desligado.' });
  }
  return json_({ ok: true, user: publicUser_(user) });
}

function decide_(ss, p) {
  ensureSheets_(ss);
  const sheet = ss.getSheetByName('usuarios');
  const users = readUsers_(sheet);
  const user = findUser_(users, p.email || p.login);
  if (!user) return json_({ ok: false, error: 'Usuário não encontrado.' });
  const status = String(p.status || '')
    .trim()
    .toLowerCase();
  if (status !== 'aprovado' && status !== 'recusado') {
    return json_({ ok: false, error: 'Status inválido.' });
  }
  const map = colMap_(sheet);
  const role = p.role || p.papel ? normalizeRole_(p.role || p.papel) : user.role;
  if (map.status >= 0) {
    sheet.getRange(user.row, map.status + 1).setValue(status);
  }
  if (map.ativo >= 0) {
    sheet.getRange(user.row, map.ativo + 1).setValue(status === 'aprovado' ? 'sim' : 'nao');
  }
  if (map.papel >= 0 && role !== 'dev') {
    sheet.getRange(user.row, map.papel + 1).setValue(role);
  }
  if (map.permissoes >= 0 && (p.permissoes || p.permissions)) {
    sheet
      .getRange(user.row, map.permissoes + 1)
      .setValue(String(p.permissoes || p.permissions || 'geral').trim());
  }
  return json_({ ok: true, users: publicUsers_(ss) });
}

function setPermissoes_(ss, p) {
  ensureSheets_(ss);
  const sheet = ss.getSheetByName('usuarios');
  const user = findUser_(readUsers_(sheet), p.email || p.login);
  if (!user) return json_({ ok: false, error: 'Usuário não encontrado.' });
  const map = colMap_(sheet);
  if (map.permissoes < 0) {
    return json_({
      ok: false,
      error: 'Atualize o script para gravar as permissões.',
    });
  }
  sheet
    .getRange(user.row, map.permissoes + 1)
    .setValue(String(p.permissoes || p.permissions || p.value || 'geral').trim());
  return json_({ ok: true, users: publicUsers_(ss) });
}

function setFuncao_(ss, p) {
  ensureSheets_(ss);
  const sheet = ss.getSheetByName('usuarios');
  const user = findUser_(readUsers_(sheet), p.email || p.login);
  if (!user) return json_({ ok: false, error: 'Usuário não encontrado.' });
  const map = colMap_(sheet);
  if (map.funcao < 0) {
    return json_({ ok: false, error: 'Atualize o script para gravar a função.' });
  }
  sheet
    .getRange(user.row, map.funcao + 1)
    .setValue(normalizeFuncao_(p.funcao || p.value || ''));
  return json_({ ok: true, users: publicUsers_(ss) });
}

function setCargo_(ss, p) {
  ensureSheets_(ss);
  const sheet = ss.getSheetByName('usuarios');
  const user = findUser_(readUsers_(sheet), p.email || p.login);
  if (!user) return json_({ ok: false, error: 'Usuário não encontrado.' });
  const map = colMap_(sheet);
  if (map.cargo < 0) {
    return json_({ ok: false, error: 'Atualize o script para gravar o cargo.' });
  }
  sheet
    .getRange(user.row, map.cargo + 1)
    .setValue(String(p.cargo || p.value || '').trim().slice(0, 80));
  return json_({ ok: true, users: publicUsers_(ss) });
}

function normalizeCalibracao_(raw) {
  const value = String(raw || '')
    .trim()
    .toLowerCase();
  if (value === 'preencher' || value === 'fill' || value === 'usar') {
    return 'preencher';
  }
  if (value === 'emitir' || value === 'issue' || value === 'certificado') {
    return 'emitir';
  }
  return 'nao';
}

function setCalibracao_(ss, p) {
  ensureSheets_(ss);
  const sheet = ss.getSheetByName('usuarios');
  const user = findUser_(readUsers_(sheet), p.email || p.login);
  if (!user) return json_({ ok: false, error: 'Usuário não encontrado.' });
  const map = colMap_(sheet);
  if (map.calibracao < 0) {
    return json_({
      ok: false,
      error: 'Atualize o script para gravar o acesso de calibração.',
    });
  }
  sheet
    .getRange(user.row, map.calibracao + 1)
    .setValue(normalizeCalibracao_(p.calibracao || p.value || ''));
  return json_({ ok: true, users: publicUsers_(ss) });
}

function setPapel_(ss, p) {
  ensureSheets_(ss);
  const sheet = ss.getSheetByName('usuarios');
  const user = findUser_(readUsers_(sheet), p.email || p.login);
  if (!user) return json_({ ok: false, error: 'Usuário não encontrado.' });
  if (user.role === 'dev') {
    return json_({ ok: false, error: 'Não altere o desenvolvedor.' });
  }
  if (user.email === 'administrativo@gssolucoestec.com.br') {
    return json_({ ok: false, error: 'O acesso principal permanece administrativo.' });
  }
  if (user.email === 'cleber@gssolucoestec.com.br') {
    return json_({ ok: false, error: 'Cleber permanece técnico e administrativo.' });
  }
  const role = normalizeRole_(p.role || p.papel);
  if (role === 'dev') {
    return json_({ ok: false, error: 'Papel inválido.' });
  }
  const map = colMap_(sheet);
  if (map.papel >= 0) {
    sheet.getRange(user.row, map.papel + 1).setValue(role);
  }
  return json_({ ok: true, users: publicUsers_(ss) });
}

function setAtivo_(ss, p) {
  ensureSheets_(ss);
  const sheet = ss.getSheetByName('usuarios');
  const user = findUser_(readUsers_(sheet), p.email || p.login);
  if (!user) return json_({ ok: false, error: 'Usuário não encontrado.' });
  if (user.role === 'dev') {
    return json_({ ok: false, error: 'Não desligue o desenvolvedor.' });
  }
  if (user.email === 'administrativo@gssolucoestec.com.br') {
    return json_({ ok: false, error: 'Não desligue o acesso principal da GS Soluções.' });
  }
  if (user.email === 'cleber@gssolucoestec.com.br') {
    return json_({ ok: false, error: 'Não desligue o acesso do Cleber.' });
  }
  const map = colMap_(sheet);
  if (map.ativo >= 0) {
    sheet.getRange(user.row, map.ativo + 1).setValue(yes_(p.value) ? 'sim' : 'nao');
  }
  return json_({ ok: true, users: publicUsers_(ss) });
}

function setSenha_(ss, p) {
  ensureSheets_(ss);
  const sheet = ss.getSheetByName('usuarios');
  const user = findUser_(readUsers_(sheet), p.email || p.login);
  if (!user) return json_({ ok: false, error: 'Usuário não encontrado.' });
  if (!passHashMatches_(user, p)) {
    return json_({
      ok: false,
      error: 'Senha atual incorreta.',
      wrongPassword: true,
    });
  }
  const newPassHash = String(p.newPassHash || '').trim();
  if (!newPassHash) {
    return json_({ ok: false, error: 'Informe a senha nova.' });
  }
  const map = colMap_(sheet);
  if (map.senha_hash >= 0) {
    sheet.getRange(user.row, map.senha_hash + 1).setValue(newPassHash);
  }
  const updated =
    findUser_(readUsers_(sheet), user.email) || user;
  return json_({ ok: true, user: publicUser_(updated) });
}

function setPerfil_(ss, p) {
  ensureSheets_(ss);
  const sheet = ss.getSheetByName('usuarios');
  const users = readUsers_(sheet);
  const user = findUser_(users, p.email || p.login);
  if (!user) return json_({ ok: false, error: 'Usuário não encontrado.' });
  if (!passHashMatches_(user, p)) {
    return json_({
      ok: false,
      error: 'Senha atual incorreta.',
      wrongPassword: true,
    });
  }
  const name = String(p.name || p.nome || user.name).trim();
  const phone = String(p.phone || p.telefone || user.phone).trim();
  const newLogin = String(p.newLogin || user.login)
    .trim()
    .toLowerCase();
  const newEmail = String(p.newEmail || user.email)
    .trim()
    .toLowerCase();
  if (!name) return json_({ ok: false, error: 'Informe o nome.' });
  if (!newLogin) return json_({ ok: false, error: 'Informe o usuário.' });
  if (!newEmail || newEmail.indexOf('@') < 0) {
    return json_({ ok: false, error: 'Informe um e-mail válido.' });
  }
  if (newLogin !== user.login) {
    const takenLogin = findUser_(users, newLogin);
    if (takenLogin && takenLogin.row !== user.row) {
      return json_({ ok: false, error: 'Este usuário já está em uso.' });
    }
    if (
      isReservedIdentity_(newLogin, '') &&
      !identityBelongsTo_(user, newLogin, newEmail)
    ) {
      return json_({
        ok: false,
        error: 'Este usuário é do acesso principal, do Cleber ou do desenvolvedor.',
      });
    }
  }
  if (newEmail !== user.email) {
    const takenEmail = findUser_(users, newEmail);
    if (takenEmail && takenEmail.row !== user.row) {
      return json_({ ok: false, error: 'Este e-mail já está em uso.' });
    }
  }
  const map = colMap_(sheet);
  if (map.nome >= 0) {
    sheet.getRange(user.row, map.nome + 1).setValue(name);
  }
  if (map.telefone >= 0) {
    sheet.getRange(user.row, map.telefone + 1).setValue(phone);
  }
  if (map.login >= 0) {
    sheet.getRange(user.row, map.login + 1).setValue(newLogin);
  }
  if (map.email >= 0) {
    sheet.getRange(user.row, map.email + 1).setValue(newEmail);
  }
  const newPassHash = String(p.newPassHash || '').trim();
  if (newPassHash && map.senha_hash >= 0) {
    sheet.getRange(user.row, map.senha_hash + 1).setValue(newPassHash);
  }
  const updated =
    findUser_(readUsers_(sheet), newEmail) ||
    findUser_(readUsers_(sheet), newLogin) ||
    user;
  return json_({ ok: true, user: publicUser_(updated) });
}

function identityBelongsTo_(user, login, email) {
  if (user.login === login || user.email === email) return true;
  if (
    user.email === 'administrativo@gssolucoestec.com.br' &&
    isPrincipalLookup_(login)
  ) {
    return true;
  }
  if (user.email === 'cleber@gssolucoestec.com.br' && isCleberLookup_(login)) {
    return true;
  }
  return false;
}

function isBlocked_(ss) {
  const sheet = ss.getSheetByName('controle');
  if (!sheet) return false;
  const values = sheet.getDataRange().getValues();
  for (var i = 1; i < values.length; i++) {
    if (String(values[i][0]).toLowerCase() === 'cleber_bloqueado') {
      return yes_(values[i][1]);
    }
  }
  return false;
}

function setBlocked_(ss, blocked) {
  ensureSheets_(ss);
  const sheet = ss.getSheetByName('controle');
  const values = sheet.getDataRange().getValues();
  for (var i = 1; i < values.length; i++) {
    if (String(values[i][0]).toLowerCase() === 'cleber_bloqueado') {
      sheet.getRange(i + 1, 2).setValue(blocked ? 'sim' : 'nao');
      return;
    }
  }
  sheet.appendRow(['cleber_bloqueado', blocked ? 'sim' : 'nao']);
}

function yes_(value) {
  const raw = String(value == null ? '' : value)
    .trim()
    .toLowerCase();
  return raw === 'sim' || raw === '1' || raw === 'true';
}

const OS_HEADERS = ['id', 'number', 'status', 'json', 'atualizado_em'];

function ensureOsSheet_(ss) {
  var sheet = ss.getSheetByName('ordens');
  if (!sheet) {
    sheet = ss.insertSheet('ordens');
    sheet.appendRow(OS_HEADERS);
  }
  return sheet;
}

function parseJson_(raw, fallback) {
  try {
    const text = String(raw == null ? '' : raw).trim();
    if (text.charAt(0) === '[' || text.charAt(0) === '{') {
      return JSON.parse(text);
    }
  } catch (error) {}
  return fallback;
}

function findOrder_(ss, id) {
  const sheet = ensureOsSheet_(ss);
  const data = sheet.getDataRange().getValues();
  for (var i = 1; i < data.length; i++) {
    if (String(data[i][0]) !== id) continue;
    // Save/merge precisa do JSON completo do Drive.
    const record = readOrderRecord_(data[i][3], { forceFull: true }) || {};
    return { sheet: sheet, row: i + 1, record: record };
  }
  return { sheet: sheet, row: -1, record: {} };
}

function isDriveLimitError_(error) {
  const msg = String((error && error.message) || error || '');
  return /limit|limite|rate|too many|muitas vezes|quota|storage|armazenamento/i.test(
    msg,
  );
}

/**
 * Cota cheia de verdade (não é rajada "Limite excedido: Drive").
 * A mensagem genérica do Apps Script costuma ser rate/limit da conta
 * que implantou o script — retry ajuda; culpar o administrativo@ não.
 */
function isDriveStorageError_(error) {
  const msg = String((error && error.message) || error || '').toLowerCase();
  if (/armazenamento cheio|storage quota|quota.*exceeded|insufficient.*storage/.test(msg)) {
    return true;
  }
  // "quota" sozinho sem "limite excedido: drive" (ex.: storageQuotaExceeded).
  if (/storage|armazenamento/.test(msg)) return true;
  if (/quota/.test(msg) && !/limite excedido/.test(msg)) return true;
  return false;
}

function driveScriptAccount_() {
  var mail = '';
  try {
    mail = String(Session.getEffectiveUser().getEmail() || '')
      .trim()
      .toLowerCase();
  } catch (error) {}
  if (mail.indexOf('@') > 0) return mail;
  try {
    mail = String(Session.getActiveUser().getEmail() || '')
      .trim()
      .toLowerCase();
  } catch (error) {}
  if (mail.indexOf('@') > 0) return mail;
  // Editor às vezes não devolve e-mail até o escopo userinfo.email; tenta o Drive.
  try {
    const about = UrlFetchApp.fetch(
      'https://www.googleapis.com/drive/v3/about?fields=user(emailAddress)',
      {
        method: 'get',
        headers: { Authorization: 'Bearer ' + ScriptApp.getOAuthToken() },
        muteHttpExceptions: true,
      },
    );
    if (about.getResponseCode() >= 200 && about.getResponseCode() < 300) {
      const json = JSON.parse(about.getContentText() || '{}');
      mail = String((json.user && json.user.emailAddress) || '')
        .trim()
        .toLowerCase();
    }
  } catch (error) {}
  if (mail.indexOf('@') > 0) return mail;
  try {
    const owner = DriveApp.getRootFolder().getOwner();
    if (owner) {
      mail = String(owner.getEmail() || '')
        .trim()
        .toLowerCase();
    }
  } catch (error) {}
  return mail.indexOf('@') > 0 ? mail : '';
}

/** Repete a operação quando o Drive recusa por rajada ("Limite excedido: Drive"). */
function driveRetry_(fn) {
  var wait = 1200;
  for (var attempt = 0; ; attempt++) {
    try {
      return fn();
    } catch (error) {
      // Cota cheia: não adianta insistir.
      if (isDriveStorageError_(error) && attempt >= 1) throw error;
      if (attempt >= 5 || !isDriveLimitError_(error)) throw error;
      Utilities.sleep(wait);
      wait = Math.min(wait * 2, 15000);
    }
  }
}

/**
 * Grava ou sobrescreve o arquivo na pasta.
 * Antes: lixeira + arquivo novo (estourava cota e o limite do Drive).
 * Agora: atualiza o conteúdo do arquivo existente (Drive API v3).
 */
function upsertDriveFile_(folder, blob, conflict) {
  return driveRetry_(function () {
    const name = blob.getName();
    const found = driveFindFiles_(folder, name);
    if (found.length === 0) {
      return folder.createFile(blob);
    }
    if (String(conflict || 'replace').toLowerCase() === 'rename') {
      blob.setName(uniqueDriveName_(folder, name));
      return folder.createFile(blob);
    }
    const file = found[0];
    for (var i = 1; i < found.length; i++) {
      try {
        found[i].setTrashed(true);
      } catch (error) {}
    }
    // Preferência: PATCH via Drive API (não gasta cota com lixeira).
    // Sem escopo script.external_request o UrlFetchApp estoura — cai no
    // fallback DriveApp (lixeira + arquivo novo) para não travar o técnico.
    try {
      const res = UrlFetchApp.fetch(
        'https://www.googleapis.com/upload/drive/v3/files/' +
          encodeURIComponent(file.getId()) +
          '?uploadType=media&supportsAllDrives=true',
        {
          method: 'patch',
          contentType: blob.getContentType() || 'application/octet-stream',
          payload: blob.getBytes(),
          headers: {
            Authorization: 'Bearer ' + ScriptApp.getOAuthToken(),
          },
          muteHttpExceptions: true,
        },
      );
      const code = res.getResponseCode();
      if (code >= 200 && code < 300) return file;
      const body = String(res.getContentText() || '');
      if (isDriveLimitError_(body) || isDriveLimitError_('HTTP ' + code)) {
        throw new Error(body || 'Limite excedido: Drive.');
      }
    } catch (error) {
      if (isDriveLimitError_(error)) throw error;
      // Permissão UrlFetchApp / outro erro de rede: segue no fallback.
    }
    try {
      file.setTrashed(true);
    } catch (error) {}
    return folder.createFile(blob);
  });
}

/** Pasta pelo nome com id guardado — evita busca no Drive a cada gravação. */
function namedFolder_(name) {
  const props = PropertiesService.getScriptProperties();
  const key = 'folderId:' + name;
  const cached = props.getProperty(key);
  if (cached) {
    try {
      const folder = DriveApp.getFolderById(cached);
      if (!folder.isTrashed()) return folder;
    } catch (error) {}
  }
  const folders = DriveApp.getFoldersByName(name);
  const folder = folders.hasNext()
    ? folders.next()
    : DriveApp.createFolder(name);
  props.setProperty(key, folder.getId());
  return folder;
}

/**
 * JSON grande no Drive: sobrescreve o arquivo anterior em vez de lixeira +
 * arquivo novo (cada OS salva gerava 4–5 operações e estourava a cota).
 */
function writePayloadFile_(folderName, oldFileId, fileName, json) {
  return driveRetry_(function () {
    var file = null;
    if (oldFileId) {
      try {
        file = DriveApp.getFileById(oldFileId);
        if (file.isTrashed()) file = null;
      } catch (error) {
        if (isDriveLimitError_(error)) throw error;
        file = null;
      }
    }
    if (file) {
      file.setContent(json);
      return file;
    }
    return namedFolder_(folderName).createFile(
      Utilities.newBlob(json, 'application/json', fileName),
    );
  });
}

function trashPayloadFile_(fileId) {
  if (!fileId) return;
  try {
    DriveApp.getFileById(fileId).setTrashed(true);
  } catch (error) {}
}

/** Pasta no Drive para JSON de OS que não cabe na célula (~50k). */
function orderPayloadFolder_() {
  return namedFolder_('GS Campo - Ordens JSON');
}

function writeOrderPayload_(id, number, record, previousRaw) {
  const clean = Object.assign({}, record || {});
  delete clean._fileId;
  const json = JSON.stringify(clean);
  var oldFileId = '';
  try {
    if (typeof previousRaw === 'string' && previousRaw.charAt(0) === '{') {
      const prev = JSON.parse(previousRaw);
      if (prev && prev._fileId) oldFileId = String(prev._fileId);
    } else if (
      previousRaw &&
      typeof previousRaw === 'object' &&
      previousRaw._fileId
    ) {
      oldFileId = String(previousRaw._fileId);
    }
  } catch (error) {}

  if (json.length > 45000) {
    const file = writePayloadFile_(
      'GS Campo - Ordens JSON',
      oldFileId,
      id + '_' + String(number || clean.number || 'os').slice(0, 60),
      json,
    );
    const slots = Array.isArray(clean.calibrationSlots)
      ? clean.calibrationSlots
      : [];
    const rdo = clean.rdo && typeof clean.rdo === 'object' ? clean.rdo : {};
    // Stub leve na célula: lista/reativação rápidas sem ler o Drive.
    return JSON.stringify({
      id: id,
      number: number || clean.number || '',
      status: clean.status || '',
      updatedAt: clean.updatedAt || new Date().toISOString(),
      ownerEmail: clean.ownerEmail || '',
      createdAt: clean.createdAt || '',
      technicianName: clean.technicianName || '',
      technicianEmail: clean.technicianEmail || '',
      technicianEmails: clean.technicianEmails || '',
      startsAt: clean.startsAt || '',
      rdo: {
        client: String(rdo.client || ''),
        site: String(rdo.site || ''),
        cnpj: String(rdo.cnpj || ''),
        systemType: String(rdo.systemType || ''),
        service: String(rdo.service || ''),
      },
      calibrationSlots: slots.map(function (s) {
        s = s || {};
        return {
          id: String(s.id || ''),
          kind: String(s.kind || ''),
          certificateNumber: String(s.certificateNumber || ''),
          serialNumber: String(s.serialNumber || ''),
          equipmentTag: String(s.equipmentTag || ''),
          jobId: String(s.jobId || ''),
        };
      }),
      _fileId: file.getId(),
      _payloadLight: true,
    });
  }

  trashPayloadFile_(oldFileId);
  return json;
}

function writeGenericPayload_(folderName, id, label, record, previousRaw) {
  const clean = Object.assign({}, record || {});
  delete clean._fileId;
  const json = JSON.stringify(clean);
  var oldFileId = '';
  try {
    if (typeof previousRaw === 'string' && previousRaw.charAt(0) === '{') {
      const prev = JSON.parse(previousRaw);
      if (prev && prev._fileId) oldFileId = String(prev._fileId);
    } else if (
      previousRaw &&
      typeof previousRaw === 'object' &&
      previousRaw._fileId
    ) {
      oldFileId = String(previousRaw._fileId);
    }
  } catch (error) {}

  if (json.length > 45000) {
    const file = writePayloadFile_(
      folderName,
      oldFileId,
      id + '_' + String(label || clean.number || 'item').slice(0, 60),
      json,
    );
    return JSON.stringify({
      id: id,
      number: label || clean.number || '',
      status: clean.status || '',
      kind: clean.kind || '',
      clientName: clean.clientName || '',
      osId: clean.osId || '',
      osNumber: clean.osNumber || '',
      calibrationSlotId: clean.calibrationSlotId || '',
      equipmentTag: clean.equipmentTag || '',
      equipmentType: clean.equipmentType || '',
      serialNumber: clean.serialNumber || '',
      calibrationDate: clean.calibrationDate || '',
      updatedAt: clean.updatedAt || new Date().toISOString(),
      ownerEmail: clean.ownerEmail || '',
      createdAt: clean.createdAt || '',
      _fileId: file.getId(),
      _payloadLight: true,
    });
  }

  if (oldFileId) {
    try {
      DriveApp.getFileById(oldFileId).setTrashed(true);
    } catch (error) {}
  }
  return json;
}

function parseOrderCell_(raw) {
  try {
    if (raw && typeof raw === 'object' && !Array.isArray(raw)) return raw;
    const text = String(raw == null ? '' : raw).trim();
    if (text.charAt(0) !== '{') return null;
    return JSON.parse(text);
  } catch (error) {
    return null;
  }
}

function readOrderRecord_(raw, opt) {
  const forceFull = opt && opt.forceFull === true;
  var parsed;
  try {
    parsed = parseOrderCell_(raw);
  } catch (error) {
    return null;
  }
  if (!parsed || typeof parsed !== 'object') return null;
  // listos: nunca lê Drive (rápido). getos/save usa forceFull.
  if (!forceFull || !parsed._fileId) return parsed;
  // Devolver o resumo aqui fez o save regravar OS sem RDOs e slots completos.
  return readPayloadFile_(parsed._fileId, 'a OS ' + (parsed.number || parsed.id || ''));
}

function readPayloadFile_(fileId, label) {
  var loaded = null;
  try {
    loaded = JSON.parse(
      DriveApp.getFileById(String(fileId)).getBlob().getDataAsString(),
    );
  } catch (error) {
    throw new Error(
      'Não leu o arquivo completo d' + label + ' no Drive (' +
        String((error && error.message) || error) +
        '). Nada foi gravado; tente de novo mais tarde.',
    );
  }
  if (!loaded || typeof loaded !== 'object') {
    throw new Error('Arquivo d' + label + ' no Drive está vazio. Nada foi gravado.');
  }
  return loaded;
}

function writeOrder_(found, record) {
  const id = String(record.id || '');
  const number = String(record.number || '');
  const status = String(record.status || '');
  const now = new Date();
  var previousRaw = '';
  if (found.row >= 0) {
    try {
      previousRaw = found.sheet.getRange(found.row, 4).getValue();
    } catch (error) {}
  }
  const cellValue = writeOrderPayload_(id, number, record, previousRaw);
  if (found.row < 0) {
    found.sheet.appendRow([id, number, status, cellValue, now]);
  } else {
    found.sheet.getRange(found.row, 1, 1, 5).setValues([
      [id, number, status, cellValue, now],
    ]);
  }
}

function mergeFiles_(existing, incoming) {
  const extra = Array.isArray(incoming) ? incoming : [];
  if (extra.length === 0) return Array.isArray(existing) ? existing : [];
  const map = {};
  function key_(file) {
    return String((file && file.kind) || '') + '|' + String((file && file.name) || '');
  }
  const current = Array.isArray(existing) ? existing : [];
  for (var i = 0; i < current.length; i++) {
    map[key_(current[i])] = current[i];
  }
  for (var j = 0; j < extra.length; j++) {
    map[key_(extra[j])] = extra[j];
  }
  const out = [];
  for (const key in map) {
    out.push(map[key]);
  }
  return out;
}

function mergeById_(existing, incoming) {
  const current = Array.isArray(existing) ? existing : [];
  const extra = Array.isArray(incoming) ? incoming : [];
  if (extra.length === 0) return current;
  const map = {};
  for (var i = 0; i < current.length; i++) {
    const item = current[i];
    if (item && item.id) map[String(item.id)] = item;
  }
  for (var j = 0; j < extra.length; j++) {
    const item = extra[j];
    if (item && item.id) map[String(item.id)] = item;
  }
  const out = [];
  for (const key in map) {
    out.push(map[key]);
  }
  return out;
}

function dropDeletedRdos_(rdos, rawIds) {
  const list = Array.isArray(rdos) ? rdos : [];
  const gone = {};
  String(rawIds || '')
    .split(/[,;|]/)
    .forEach(function (id) {
      const key = String(id || '').trim();
      if (key) gone[key] = true;
    });
  if (!Object.keys(gone).length) return list;
  return list.filter(function (item) {
    return item && item.id && !gone[String(item.id)];
  });
}

function parseTimeMs_(value) {
  if (value == null || value === '') return 0;
  if (Object.prototype.toString.call(value) === '[object Date]') {
    const t = value.getTime();
    return isNaN(t) ? 0 : t;
  }
  const text = String(value).trim();
  if (!text) return 0;
  const t = Date.parse(text);
  return isNaN(t) ? 0 : t;
}

function isClosedOsStatus_(status) {
  const s = String(status || '').trim();
  return s === 'encerrada' || s === 'servicoEncerrado';
}

/** Evita cache antigo de outra máquina re-encerrar OS já reativada. */
function preferOsStatus_(incoming, previous, incomingAt, previousAt) {
  const a = String(incoming || '').trim();
  const b = String(previous || '').trim();
  if (!a) return b || 'comTecnico';
  if (!b) return a;
  const ta = parseTimeMs_(incomingAt);
  const tb = parseTimeMs_(previousAt);
  if (ta && tb && ta < tb) return b;
  if (ta && tb && ta > tb) return a;
  // Sem timestamp confiável: reativação (fechada → aberta) sempre entra.
  if (isClosedOsStatus_(b) && !isClosedOsStatus_(a)) return a;
  // Não deixar push sem data re-fechar OS aberta na nuvem.
  if (!isClosedOsStatus_(b) && isClosedOsStatus_(a) && !(ta > tb)) return b;
  return a;
}

function hasParam_(p, name) {
  return Object.prototype.hasOwnProperty.call(p, name) &&
    String(p[name] == null ? '' : p[name]).trim() !== '';
}

function saveOs_(ss, p) {
  const id = String(p.id || '').trim();
  if (!id) return json_({ ok: false, error: 'OS sem id' });
  const found = findOrder_(ss, id);
  const prev = found.record || {};
  const incomingRdos = hasParam_(p, 'rdosJson')
    ? parseJson_(p.rdosJson, [])
    : null;
  const incomingFiles = hasParam_(p, 'filesJson')
    ? parseJson_(p.filesJson, [])
    : null;
  const incomingUpdatedAt = String(p.updatedAt || '').trim();
  const prevUpdatedAt = String(prev.updatedAt || '').trim();
  const status = preferOsStatus_(
    p.status,
    prev.status,
    incomingUpdatedAt,
    prevUpdatedAt,
  );
  const updatedAt =
    parseTimeMs_(incomingUpdatedAt) >= parseTimeMs_(prevUpdatedAt) &&
    incomingUpdatedAt
      ? incomingUpdatedAt
      : prevUpdatedAt || incomingUpdatedAt || new Date().toISOString();
  const record = {
    id: id,
    number: String(p.number || prev.number || ''),
    status: status,
    updatedAt: updatedAt,
    ownerEmail: String(p.ownerEmail || prev.ownerEmail || ''),
    createdAt: String(p.createdAt || prev.createdAt || ''),
    startsAt: String(p.startsAt || prev.startsAt || ''),
    technicianEmail: String(p.technicianEmail || prev.technicianEmail || ''),
    technicianName: String(p.technicianName || prev.technicianName || ''),
    technicianEmails: String(
      p.technicianEmails || prev.technicianEmails || '',
    ),
    signerName: String(p.signerName || prev.signerName || ''),
    rdo: {
      client: String(p.client || (prev.rdo && prev.rdo.client) || ''),
      site: String(p.site || (prev.rdo && prev.rdo.site) || ''),
      cnpj: String(p.cnpj || (prev.rdo && prev.rdo.cnpj) || ''),
      systemType: String(
        p.systemType || (prev.rdo && prev.rdo.systemType) || '',
      ),
      service: String(p.service || (prev.rdo && prev.rdo.service) || ''),
      technicianCargo: String(
        p.technicianCargo || (prev.rdo && prev.rdo.technicianCargo) || '',
      ),
      baseName: String(p.baseName || (prev.rdo && prev.rdo.baseName) || ''),
      baseCargo: String(p.baseCargo || (prev.rdo && prev.rdo.baseCargo) || ''),
      baseEmail: String(p.baseEmail || (prev.rdo && prev.rdo.baseEmail) || ''),
      basePhone: String(p.basePhone || (prev.rdo && prev.rdo.basePhone) || ''),
      technicianFuncoes: hasParam_(p, 'technicianFuncoes')
        ? parseJson_(p.technicianFuncoes, (prev.rdo && prev.rdo.technicianFuncoes) || {})
        : ((prev.rdo && prev.rdo.technicianFuncoes) || {}),
      technicianCargos: hasParam_(p, 'technicianCargos')
        ? parseJson_(p.technicianCargos, (prev.rdo && prev.rdo.technicianCargos) || {})
        : ((prev.rdo && prev.rdo.technicianCargos) || {}),
    },
    rdos: dropDeletedRdos_(
      incomingRdos == null
        ? prev.rdos || []
        : mergeById_(prev.rdos, incomingRdos),
      p.deletedRdoIds,
    ),
    files: incomingFiles == null
      ? prev.files || []
      : mergeFiles_(prev.files, incomingFiles),
    // Nunca apagar certificados da nuvem com JSON vazio (stub leve / reativar).
    calibrationSlots: (function () {
      if (!hasParam_(p, 'calibrationSlotsJson')) {
        return prev.calibrationSlots || [];
      }
      const incoming = parseJson_(p.calibrationSlotsJson, []);
      if (!Array.isArray(incoming) || incoming.length === 0) {
        return prev.calibrationSlots || [];
      }
      return incoming;
    })(),
  };
  writeOrder_(found, record);
  return json_({ ok: true, id: id, status: status, updatedAt: updatedAt });
}

function saveRdo_(ss, p) {
  const osId = String(p.osId || p.id || '').trim();
  if (!osId) return json_({ ok: false, error: 'OS sem id' });
  const found = findOrder_(ss, osId);
  if (found.row < 0 && !String(p.number || '').trim()) {
    return json_({ ok: false, error: 'OS não encontrada' });
  }
  const prev = found.record || {};
  const prevRdos = Array.isArray(prev.rdos) ? prev.rdos : [];
  var prevSame = {};
  for (var i = 0; i < prevRdos.length; i++) {
    if (String(prevRdos[i].id) === String(p.rdoId || '')) {
      prevSame = prevRdos[i];
      break;
    }
  }
  const rdo = {
    id: String(p.rdoId || Date.now()),
    date: String(p.date || ''),
    clockIn: String(p.clockIn || ''),
    lunchStart: String(p.lunchStart || ''),
    lunchEnd: String(p.lunchEnd || ''),
    clockOut: String(p.clockOut || ''),
    description: String(p.description || ''),
    notes: String(p.notes || ''),
    signed: yes_(p.signed),
    createdAt: String(p.createdAt || new Date().toISOString()),
    responsibleName: String(p.responsibleName || prevSame.responsibleName || ''),
    signedAt: String(p.signedAt || prevSame.signedAt || ''),
    signToken: String(p.signToken || prevSame.signToken || ''),
    clientSignedName: String(
      p.clientSignedName || prevSame.clientSignedName || '',
    ),
    clientSignedAt: String(p.clientSignedAt || prevSame.clientSignedAt || ''),
    files: parseJson_(p.filesJson, []),
    absent: parseJson_(
      p.absentJson,
      Array.isArray(prevSame.absent) ? prevSame.absent : [],
    ),
  };
  const record = Object.assign({}, prev, {
    id: osId,
    number: String(p.number || prev.number || ''),
    status: preferOsStatus_(
      p.status,
      prev.status,
      p.updatedAt,
      prev.updatedAt,
    ),
    updatedAt: String(p.updatedAt || prev.updatedAt || new Date().toISOString()),
    rdos: mergeById_(prev.rdos, [rdo]),
  });
  writeOrder_(found, record);
  return json_({ ok: true, id: osId, rdoId: rdo.id });
}

function readOrders_(ss) {
  const sheet = ensureOsSheet_(ss);
  const data = sheet.getDataRange().getValues();
  const orders = [];
  for (var i = 1; i < data.length; i++) {
    const id = String(data[i][0] || '').trim();
    const number = String(data[i][1] || '').trim();
    const status = String(data[i][2] || '').trim();
    var record = readOrderRecord_(data[i][3]);
    if (!record || typeof record !== 'object') {
      if (!id && !number) continue;
      record = {};
    }
    record.id = String(record.id || id || '');
    if (!record.number) record.number = number;
    if (!record.status) record.status = status || 'comTecnico';
    const sheetUpdated = data[i][4];
    if (!record.updatedAt && sheetUpdated) {
      try {
        if (Object.prototype.toString.call(sheetUpdated) === '[object Date]') {
          record.updatedAt = sheetUpdated.toISOString();
        } else {
          const text = String(sheetUpdated).trim();
          if (text) record.updatedAt = text;
        }
      } catch (error) {}
    }
    if (!record.id) continue;
    orders.push(record);
  }
  return orders;
}

function listOs_(ss) {
  return json_({ ok: true, orders: readOrders_(ss) });
}

/** Remove a OS da planilha e o JSON grande no Drive (se houver). */
function deleteOs_(ss, p) {
  const id = String(p.id || p.osId || '').trim();
  if (!id) return json_({ ok: false, error: 'OS sem id' });
  const sheet = ensureOsSheet_(ss);
  const data = sheet.getDataRange().getValues();
  for (var i = 1; i < data.length; i++) {
    if (String(data[i][0]) !== id) continue;
    try {
      const raw = String(data[i][3] || '');
      if (raw.charAt(0) === '{') {
        const stub = JSON.parse(raw);
        if (stub && stub._fileId) {
          try {
            DriveApp.getFileById(String(stub._fileId)).setTrashed(true);
          } catch (error) {}
        }
      }
    } catch (error) {}
    sheet.deleteRow(i + 1);
    return json_({ ok: true, id: id });
  }
  return json_({ ok: true, id: id });
}

/** Uma OS completa (lê Drive se precisar). Usado para hidratar certificados. */
function getOs_(ss, p) {
  const id = String(p.id || p.osId || '').trim();
  if (!id) return json_({ ok: false, error: 'OS sem id' });
  const found = findOrder_(ss, id);
  if (found.row < 0) {
    return json_({ ok: false, error: 'OS não encontrada' });
  }
  const record = found.record || {};
  record.id = String(record.id || id);
  return json_({ ok: true, order: record, orders: [record] });
}

const CLIENT_HEADERS = ['id', 'name', 'cnpj', 'json', 'atualizado_em'];

function ensureClientSheet_(ss) {
  var sheet = ss.getSheetByName('clientes');
  if (!sheet) {
    sheet = ss.insertSheet('clientes');
    sheet.appendRow(CLIENT_HEADERS);
  }
  return sheet;
}

/** Pasta no Drive para JSON de cliente que não cabe na célula (limite ~50k). */
function clientPayloadFolder_() {
  return namedFolder_('GS Campo - Clientes JSON');
}

function readClientRecord_(raw, opt) {
  const forceFull = opt && opt.forceFull === true;
  var parsed;
  try {
    if (typeof raw !== 'string' || raw.charAt(0) !== '{') return null;
    parsed = JSON.parse(raw);
    // listclients/snapshot: nunca lê Drive (rápido). getclient usa forceFull.
    if (!forceFull) {
      if (parsed && parsed._fileId && !parsed._payloadLight) {
        parsed._payloadLight = true;
      }
      return parsed;
    }
  } catch (error) {
    return null;
  }
  if (!parsed || !parsed._fileId) return parsed;
  // Resumo no lugar do cadastro apagava responsáveis e ilhas nos aparelhos.
  return readPayloadFile_(parsed._fileId, 'o cliente ' + (parsed.name || parsed.id || ''));
}

function writeClientPayload_(id, record, previousRaw) {
  const json = JSON.stringify(record);
  var oldFileId = '';
  try {
    if (typeof previousRaw === 'string' && previousRaw.charAt(0) === '{') {
      const prev = JSON.parse(previousRaw);
      if (prev && prev._fileId) oldFileId = String(prev._fileId);
    }
  } catch (error) {}

  // Célula do Sheets aceita no máximo ~50.000 caracteres.
  if (json.length > 45000) {
    const file = writePayloadFile_(
      'GS Campo - Clientes JSON',
      oldFileId,
      id + '_' + String(record.name || 'cliente').slice(0, 60),
      json,
    );
    return JSON.stringify({
      id: id,
      name: record.name || '',
      cnpj: record.cnpj || '',
      updatedAt: record.updatedAt || new Date().toISOString(),
      _fileId: file.getId(),
      _payloadLight: true,
    });
  }

  if (oldFileId) {
    try {
      DriveApp.getFileById(oldFileId).setTrashed(true);
    } catch (error) {}
  }
  return json;
}

const STAFF_DOC_HEADERS = [
  'id',
  'staffEmail',
  'name',
  'kind',
  'createdAt',
  'requiresSignature',
  'signedAt',
  'signedBy',
  'fileId',
  'signFileId',
];

function ensureStaffDocsSheet_(ss) {
  var sheet = ss.getSheetByName('staff_docs');
  if (!sheet) {
    sheet = ss.insertSheet('staff_docs');
    sheet.appendRow(STAFF_DOC_HEADERS);
  }
  return sheet;
}

function staffDocsFolder_() {
  const name = 'GS Campo - RH Documentos';
  const folders = DriveApp.getFoldersByName(name);
  if (folders.hasNext()) return folders.next();
  return DriveApp.createFolder(name);
}

function staffDocRowMap_(headers, row) {
  const out = {};
  for (var i = 0; i < headers.length; i++) {
    out[headers[i]] = row[i];
  }
  return out;
}

function staffDocPublic_(row) {
  return {
    id: String(row.id || ''),
    staffEmail: String(row.staffEmail || '').toLowerCase(),
    name: String(row.name || 'arquivo'),
    kind: String(row.kind || 'certificate'),
    createdAt: String(row.createdAt || ''),
    requiresSignature: String(row.requiresSignature || '').toLowerCase() === 'sim',
    signedAt: String(row.signedAt || ''),
    signedBy: String(row.signedBy || ''),
    path: String(row.fileId || ''),
  };
}

function saveStaffDoc_(ss, p) {
  const sheet = ensureStaffDocsSheet_(ss);
  const id = String(p.id || Utilities.getUuid()).trim();
  const staffEmail = String(p.staffEmail || '')
    .trim()
    .toLowerCase();
  if (!staffEmail || staffEmail.indexOf('@') < 0) {
    return json_({ ok: false, error: 'Documento sem e-mail do funcionário' });
  }
  var raw = String(p.data || p.base64 || '').replace(/\s/g, '');
  const marker = 'base64,';
  const cut = raw.indexOf(marker);
  if (cut >= 0) raw = raw.slice(cut + marker.length);
  if (!raw) return json_({ ok: false, error: 'Arquivo vazio' });
  var bytes;
  try {
    bytes = Utilities.base64Decode(raw);
  } catch (error) {
    return json_({ ok: false, error: 'Arquivo inválido' });
  }
  const name = String(p.name || 'arquivo')
    .replace(/[\\/:*?"<>|]/g, '-')
    .slice(0, 120);
  const mime = String(p.mime || mimeFromName_(name));
  const blob = Utilities.newBlob(bytes, mime, name);
  const file = staffDocsFolder_().createFile(blob);
  file.setName(id + '_' + name);
  const requires =
    yes_(p.requiresSignature) || String(p.requiresSignature) === 'true'
      ? 'sim'
      : 'nao';
  const createdAt = String(p.createdAt || new Date().toISOString());
  const kind = String(p.kind || 'certificate');
  const values = sheet.getDataRange().getValues();
  const headers = values[0] || STAFF_DOC_HEADERS;
  var updated = false;
  for (var r = 1; r < values.length; r++) {
    if (String(values[r][0]) === id) {
      var oldFileId = String(values[r][8] || '').trim();
      if (oldFileId && oldFileId !== file.getId()) {
        try {
          DriveApp.getFileById(oldFileId).setTrashed(true);
        } catch (e) {}
      }
      sheet.getRange(r + 1, 1, 1, headers.length).setValues([
        [
          id,
          staffEmail,
          name,
          kind,
          createdAt,
          requires,
          String(values[r][6] || ''),
          String(values[r][7] || ''),
          file.getId(),
          String(values[r][9] || ''),
        ],
      ]);
      updated = true;
      break;
    }
  }
  if (!updated) {
    sheet.appendRow([
      id,
      staffEmail,
      name,
      kind,
      createdAt,
      requires,
      '',
      '',
      file.getId(),
      '',
    ]);
  }
  return json_({
    ok: true,
    id: id,
    path: file.getId(),
    docs: [
      staffDocPublic_({
        id: id,
        staffEmail: staffEmail,
        name: name,
        kind: kind,
        createdAt: createdAt,
        requiresSignature: requires,
        signedAt: '',
        signedBy: '',
        fileId: file.getId(),
      }),
    ],
  });
}

function listStaffDocs_(ss, p) {
  const sheet = ensureStaffDocsSheet_(ss);
  const values = sheet.getDataRange().getValues();
  if (values.length < 2) return json_({ ok: true, docs: [] });
  const headers = values[0];
  const filter = String(p.staffEmail || '')
    .trim()
    .toLowerCase();
  const docs = [];
  for (var r = 1; r < values.length; r++) {
    const row = staffDocRowMap_(headers, values[r]);
    const email = String(row.staffEmail || '').toLowerCase();
    if (filter && email !== filter) continue;
    docs.push(staffDocPublic_(row));
  }
  return json_({ ok: true, docs: docs });
}

function getStaffDoc_(ss, p) {
  const sheet = ensureStaffDocsSheet_(ss);
  const id = String(p.id || '').trim();
  if (!id) return json_({ ok: false, error: 'Documento sem id' });
  const values = sheet.getDataRange().getValues();
  const headers = values[0] || STAFF_DOC_HEADERS;
  for (var r = 1; r < values.length; r++) {
    if (String(values[r][0]) !== id) continue;
    const row = staffDocRowMap_(headers, values[r]);
    const fileId = String(row.fileId || '').trim();
    if (!fileId) return json_({ ok: false, error: 'Arquivo não encontrado' });
    try {
      const file = DriveApp.getFileById(fileId);
      const bytes = file.getBlob().getBytes();
      return json_({
        ok: true,
        docs: [staffDocPublic_(row)],
        fileName: String(row.name || file.getName()),
        fileData: Utilities.base64Encode(bytes),
      });
    } catch (error) {
      return json_({ ok: false, error: 'Não leu o arquivo no Drive. ' + error });
    }
  }
  return json_({ ok: false, error: 'Documento não encontrado' });
}

function deleteStaffDoc_(ss, p) {
  const sheet = ensureStaffDocsSheet_(ss);
  const id = String(p.id || '').trim();
  if (!id) return json_({ ok: false, error: 'Documento sem id' });
  const values = sheet.getDataRange().getValues();
  for (var r = values.length - 1; r >= 1; r--) {
    if (String(values[r][0]) !== id) continue;
    const fileId = String(values[r][8] || '').trim();
    const signFileId = String(values[r][9] || '').trim();
    sheet.deleteRow(r + 1);
    try {
      if (fileId) DriveApp.getFileById(fileId).setTrashed(true);
    } catch (error) {}
    try {
      if (signFileId) DriveApp.getFileById(signFileId).setTrashed(true);
    } catch (error) {}
    return json_({ ok: true, id: id });
  }
  return json_({ ok: true, id: id });
}

function signStaffDoc_(ss, p) {
  const sheet = ensureStaffDocsSheet_(ss);
  const id = String(p.id || '').trim();
  if (!id) return json_({ ok: false, error: 'Documento sem id' });
  const signedBy = String(p.signedBy || '').trim();
  const signedAt = String(p.signedAt || new Date().toISOString());
  const values = sheet.getDataRange().getValues();
  const headers = values[0] || STAFF_DOC_HEADERS;
  for (var r = 1; r < values.length; r++) {
    if (String(values[r][0]) !== id) continue;
    var signFileId = String(values[r][9] || '');
    var raw = String(p.signData || p.data || '').replace(/\s/g, '');
    const marker = 'base64,';
    const cut = raw.indexOf(marker);
    if (cut >= 0) raw = raw.slice(cut + marker.length);
    if (raw) {
      try {
        const bytes = Utilities.base64Decode(raw);
        const signName = String(p.signName || ('assinatura_' + id + '.pdf'))
          .replace(/[\\/:*?"<>|]/g, '-')
          .slice(0, 120);
        const blob = Utilities.newBlob(
          bytes,
          String(p.signMime || 'application/pdf'),
          signName,
        );
        const file = staffDocsFolder_().createFile(blob);
        file.setName(signName);
        signFileId = file.getId();
      } catch (error) {}
    }
    sheet.getRange(r + 1, 7).setValue(signedAt);
    sheet.getRange(r + 1, 8).setValue(signedBy);
    if (signFileId) sheet.getRange(r + 1, 10).setValue(signFileId);
    const row = staffDocRowMap_(headers, sheet.getRange(r + 1, 1, 1, headers.length).getValues()[0]);
    return json_({ ok: true, docs: [staffDocPublic_(row)] });
  }
  return json_({ ok: false, error: 'Documento não encontrado' });
}

function parseJsonObject_(raw) {
  try {
    const value = String(raw || '').trim();
    if (value.charAt(0) === '{') return JSON.parse(value);
  } catch (error) {}
  return {};
}

function parseJsonArray_(raw) {
  if (Array.isArray(raw)) return raw;
  try {
    const parsed = JSON.parse(String(raw || '[]'));
    return Array.isArray(parsed) ? parsed : [];
  } catch (error) {
    return [];
  }
}

function saveClient_(ss, p) {
  const extra = parseJsonObject_(p.payload || p.json);
  const id = String(p.id || extra.id || '').trim();
  if (!id) return json_({ ok: false, error: 'Cliente sem id' });
  const record = Object.assign({}, extra, {
    id: id,
    name: String(p.name || extra.name || ''),
    requester: String(p.requester || extra.requester || ''),
    cnpj: String(p.cnpj || extra.cnpj || ''),
    sites: String(p.sites || extra.sites || ''),
    cep: String(p.cep || extra.cep || ''),
    street: String(p.street || extra.street || ''),
    number: String(p.number || extra.number || ''),
    complement: String(p.complement || extra.complement || ''),
    neighborhood: String(p.neighborhood || extra.neighborhood || ''),
    city: String(p.city || extra.city || ''),
    state: String(p.state || extra.state || ''),
    service: String(p.service || extra.service || ''),
    systemType: String(p.systemType || extra.systemType || ''),
    baseName: String(p.baseName || extra.baseName || ''),
    baseCargo: String(p.baseCargo || extra.baseCargo || ''),
    baseEmail: String(p.baseEmail || extra.baseEmail || ''),
    basePhone: String(p.basePhone || extra.basePhone || ''),
    equipment: parseJsonArray_(p.equipment || extra.equipment),
    systems: parseJsonArray_(p.systems || extra.systems),
    updatedAt: String(p.updatedAt || extra.updatedAt || new Date().toISOString()),
  });
  delete record._fileId;
  const sheet = ensureClientSheet_(ss);
  const data = sheet.getDataRange().getValues();
  var row = -1;
  var previousRaw = '';
  for (var i = 1; i < data.length; i++) {
    if (String(data[i][0]) === id) {
      row = i + 1;
      previousRaw = data[i][3];
      break;
    }
  }

  // Cópia antiga do telefone não pode ressuscitar sistema/equipamento
  // apagado no notebook (certificado da adm com instrumento fantasma).
  if (row > 0 && previousRaw && !yes_(p.restore)) {
    var previousRec = null;
    try {
      previousRec = readClientRecord_(previousRaw, { forceFull: false });
      // Stub leve: updatedAt já vem no resumo; full só se faltar data.
      if (
        previousRec &&
        previousRec._fileId &&
        !String(previousRec.updatedAt || '').trim()
      ) {
        previousRec = readClientRecord_(previousRaw, { forceFull: true });
      }
    } catch (error) {
      previousRec = null;
    }
    if (
      previousRec &&
      parseTimeMs_(previousRec.updatedAt) > parseTimeMs_(record.updatedAt)
    ) {
      return json_({
        ok: true,
        id: id,
        skipped: true,
        reason: 'preserve_newer_client',
        updatedAt: String(previousRec.updatedAt || ''),
      });
    }
  }

  var cellJson;
  try {
    cellJson = writeClientPayload_(id, record, previousRaw);
  } catch (error) {
    return json_({
      ok: false,
      error: 'Não gravou o cadastro do cliente. ' + String(error),
    });
  }
  const now = new Date();
  if (row < 0) {
    sheet.appendRow([id, record.name, record.cnpj, cellJson, now]);
  } else {
    sheet.getRange(row, 1, 1, 5).setValues([
      [id, record.name, record.cnpj, cellJson, now],
    ]);
  }
  return json_({ ok: true, id: id, updatedAt: record.updatedAt });
}

function readClients_(ss) {
  const sheet = ensureClientSheet_(ss);
  const data = sheet.getDataRange().getValues();
  const clients = [];
  for (var i = 1; i < data.length; i++) {
    const parsed = readClientRecord_(data[i][3]);
    if (parsed) clients.push(parsed);
  }
  return clients;
}

function listClients_(ss) {
  return json_({ ok: true, clients: readClients_(ss) });
}

/** Um cliente completo (lê Drive se precisar). */
function getClient_(ss, p) {
  const id = String(p.id || p.clientId || '').trim();
  if (!id) return json_({ ok: false, error: 'Cliente sem id' });
  const sheet = ensureClientSheet_(ss);
  const data = sheet.getDataRange().getValues();
  for (var i = 1; i < data.length; i++) {
    if (String(data[i][0]) !== id) continue;
    const record = readClientRecord_(data[i][3], { forceFull: true }) || {};
    record.id = String(record.id || id);
    return json_({ ok: true, clients: [record], client: record });
  }
  return json_({ ok: false, error: 'Cliente não encontrado' });
}

function deleteClient_(ss, p) {
  const id = String(p.id || '').trim();
  if (!id) return json_({ ok: false, error: 'Cliente sem id' });
  const sheet = ensureClientSheet_(ss);
  const data = sheet.getDataRange().getValues();
  for (var i = 1; i < data.length; i++) {
    if (String(data[i][0]) === id) {
      try {
        const parsed = readClientRecord_(data[i][3]);
        // readClientRecord_ already expands Drive; check stub in cell
        const raw = String(data[i][3] || '');
        if (raw.charAt(0) === '{') {
          const stub = JSON.parse(raw);
          if (stub && stub._fileId) {
            try {
              DriveApp.getFileById(String(stub._fileId)).setTrashed(true);
            } catch (error) {}
          }
        }
      } catch (error) {}
      sheet.deleteRow(i + 1);
      return json_({ ok: true, id: id });
    }
  }
  return json_({ ok: true, id: id });
}

const STANDARD_HEADERS = ['id', 'name', 'type', 'serial', 'json', 'atualizado_em'];

function ensureStandardsSheet_(ss) {
  var sheet = ss.getSheetByName('padroes');
  if (!sheet) {
    sheet = ss.insertSheet('padroes');
    sheet.appendRow(STANDARD_HEADERS);
  }
  return sheet;
}

function saveStandard_(ss, p) {
  const extra = parseJsonObject_(p.payload || p.json);
  const id = String(p.id || extra.id || '').trim();
  if (!id) return json_({ ok: false, error: 'Padrão sem id' });
  const record = Object.assign({}, extra, {
    id: id,
    name: String(p.name || extra.name || ''),
    type: String(p.type || extra.type || 'Outro'),
    serial: String(p.serial || extra.serial || ''),
    certificate: String(p.certificate || extra.certificate || ''),
    validity: String(p.validity || extra.validity || ''),
    uncertainty: String(p.uncertainty || extra.uncertainty || ''),
    coverageK: String(p.coverageK || extra.coverageK || ''),
    updatedAt: String(p.updatedAt || extra.updatedAt || new Date().toISOString()),
  });
  const sheet = ensureStandardsSheet_(ss);
  const data = sheet.getDataRange().getValues();
  var row = -1;
  for (var i = 1; i < data.length; i++) {
    if (String(data[i][0]) === id) {
      row = i + 1;
      break;
    }
  }
  const json = JSON.stringify(record);
  const now = new Date();
  if (row < 0) {
    sheet.appendRow([id, record.name, record.type, record.serial, json, now]);
  } else {
    sheet.getRange(row, 1, 1, 6).setValues([
      [id, record.name, record.type, record.serial, json, now],
    ]);
  }
  return json_({ ok: true, id: id });
}

function readStandards_(ss) {
  const sheet = ensureStandardsSheet_(ss);
  const data = sheet.getDataRange().getValues();
  const list = [];
  for (var i = 1; i < data.length; i++) {
    const raw = data[i][4];
    try {
      if (typeof raw === 'string' && raw.charAt(0) === '{') {
        list.push(JSON.parse(raw));
      }
    } catch (error) {}
  }
  return list;
}

function listStandards_(ss) {
  return json_({ ok: true, standards: readStandards_(ss) });
}

function deleteStandard_(ss, p) {
  const id = String(p.id || '').trim();
  if (!id) return json_({ ok: false, error: 'Padrão sem id' });
  const sheet = ensureStandardsSheet_(ss);
  const data = sheet.getDataRange().getValues();
  for (var i = 1; i < data.length; i++) {
    if (String(data[i][0]) === id) {
      sheet.deleteRow(i + 1);
      return json_({ ok: true, id: id });
    }
  }
  return json_({ ok: true, id: id });
}

const CALIB_HEADERS = ['id', 'number', 'kind', 'clientName', 'json', 'atualizado_em'];

function ensureCalibsSheet_(ss) {
  var sheet = ss.getSheetByName('calibracoes');
  if (!sheet) {
    sheet = ss.insertSheet('calibracoes');
    sheet.appendRow(CALIB_HEADERS);
  }
  return sheet;
}

function calibFillCount_(rec) {
  if (!rec || typeof rec !== 'object') return 0;
  var n = 0;
  var points = rec.points || [];
  for (var i = 0; i < points.length; i++) {
    var ver = (points[i] && points[i].verification) || [];
    for (var j = 0; j < ver.length; j++) {
      var o = ver[j].objectVolume;
      var s = ver[j].standardVolume;
      if ((o !== null && o !== '' && o !== 0) || (s !== null && s !== '' && s !== 0)) {
        n++;
      }
    }
  }
  var generic = rec.genericPoints || [];
  for (var g = 0; g < generic.length; g++) {
    if (generic[g] && (generic[g].objectValue || generic[g].standardValue)) n++;
  }
  var channels = rec.telemetryChannels || [];
  for (var c = 0; c < channels.length; c++) {
    var reads = (channels[c] && channels[c].readings) || [];
    if (reads.length) n += reads.length;
  }
  return n;
}

function calibTime_(value) {
  const t = new Date(String(value || '')).getTime();
  return isNaN(t) ? 0 : t;
}

function calibStrength_(rec) {
  if (!rec || typeof rec !== 'object') return 0;
  var score = 0;
  var st = String(rec.status || '');
  if (st === 'done') score += 100;
  else if (st === 'pendingReview') score += 50;
  else if (st === 'inProgress') score += 20;
  var fills = calibFillCount_(rec);
  score += Math.min(40, fills * 4);
  if (String(rec.fluid || '').trim()) score += 3;
  if (String(rec.equipmentTag || '').trim()) score += 2;
  return score;
}

function calibIsGhost_(rec) {
  if (!rec) return true;
  var st = String(rec.status || '');
  if (st === 'done' || st === 'pendingReview') return false;
  return calibFillCount_(rec) === 0;
}

function saveCalib_(ss, p) {
  const extra = parseJsonObject_(p.payload || p.json);
  const id = String(p.id || extra.id || '').trim();
  if (!id) return json_({ ok: false, error: 'Calibração sem id' });
  const record = Object.assign({}, extra, {
    id: id,
    number: String(p.number || extra.number || ''),
    kind: String(p.kind || extra.kind || ''),
    clientName: String(p.clientName || extra.clientName || ''),
    updatedAt: String(p.updatedAt || extra.updatedAt || new Date().toISOString()),
  });
  if (!yes_(p.restore) && readCalibTombstones_(ss).indexOf(id) >= 0) {
    return json_({ ok: true, id: id, skipped: true, reason: 'deleted' });
  }
  const sheet = ensureCalibsSheet_(ss);
  const data = sheet.getDataRange().getValues();
  var row = -1;
  var previousRaw = '';
  var previousRec = null;
  const needle = String(record.number || '').trim().toLowerCase();
  var strongerSameNumber = null;
  for (var i = 1; i < data.length; i++) {
    const rowId = String(data[i][0]);
    if (rowId === id) {
      row = i + 1;
      previousRaw = data[i][4];
      previousRec = readOrderRecord_(previousRaw, { forceFull: true });
    }
    if (needle) {
      const other = readOrderRecord_(data[i][4], { forceFull: false });
      if (other && String(other.id || rowId) !== id) {
        const otherNum = String(other.number || data[i][1] || '')
          .trim()
          .toLowerCase();
        if (otherNum === needle) {
          // Lista leve pode não ter fills — força full só se parecer candidato.
          var full = other;
          if (calibIsGhost_(record) || String(other.status || '') === 'done') {
            try {
              full = readOrderRecord_(data[i][4], { forceFull: true }) || other;
            } catch (error) {
              full = other;
            }
          }
          if (
            !strongerSameNumber ||
            calibStrength_(full) > calibStrength_(strongerSameNumber)
          ) {
            strongerSameNumber = full;
          }
        }
      }
    }
  }

  // Cópia antiga de um aparelho não volta por cima da versão corrigida mais nova.
  if (
    previousRec &&
    !yes_(p.restore) &&
    calibTime_(previousRec.updatedAt) > calibTime_(record.updatedAt) &&
    calibStrength_(previousRec) >= calibStrength_(record)
  ) {
    return json_({
      ok: true,
      id: id,
      skipped: true,
      reason: 'preserve_newer_same_id',
    });
  }

  // O app nunca rebaixa certificado concluído; se chegar assim, é um
  // aparelho desatualizado editando a cópia velha.
  if (
    previousRec &&
    !yes_(p.restore) &&
    String(previousRec.status || '') === 'done' &&
    String(record.status || '') !== 'done'
  ) {
    return json_({
      ok: true,
      id: id,
      skipped: true,
      reason: 'preserve_done',
    });
  }

  // Não deixa rascunho vazio apagar certificado feito (mesmo id).
  if (previousRec && calibIsGhost_(record) && calibStrength_(previousRec) > calibStrength_(record)) {
    return json_({
      ok: true,
      id: id,
      skipped: true,
      reason: 'preserve_stronger_same_id',
    });
  }
  // Não cria/atualiza fantasma se outro id já tem o mesmo nº com dados.
  if (
    calibIsGhost_(record) &&
    strongerSameNumber &&
    String(strongerSameNumber.id || '') !== id &&
    calibStrength_(strongerSameNumber) > calibStrength_(record)
  ) {
    return json_({
      ok: true,
      id: id,
      skipped: true,
      reason: 'preserve_stronger_same_number',
    });
  }

  const json = writeGenericPayload_(
    'GS Campo - Calibracoes JSON',
    id,
    record.number || 'calib',
    record,
    previousRaw,
  );
  const now = new Date();
  if (row < 0) {
    sheet.appendRow([id, record.number, record.kind, record.clientName, json, now]);
  } else {
    sheet.getRange(row, 1, 1, 6).setValues([
      [id, record.number, record.kind, record.clientName, json, now],
    ]);
  }
  return json_({ ok: true, id: id });
}

function readCalibs_(ss) {
  const sheet = ensureCalibsSheet_(ss);
  const data = sheet.getDataRange().getValues();
  const list = [];
  for (var i = 1; i < data.length; i++) {
    const loaded = readOrderRecord_(data[i][4]);
    if (loaded && typeof loaded === 'object') list.push(loaded);
  }
  return list;
}

const CERT_KIND_LABELS_ = {
  volumetric: 'Certificado de Vazão',
  volumetricInverted: 'Certificado de Vazão',
  temperature: 'Certificado de Temperatura',
  temperatureMesh: 'Certificado de Malha de Temperatura',
  density: 'Certificado de Densidade',
  pressure: 'Certificado de Pressão',
  conductivity: 'Certificado de Condutividade',
  telemetry: 'Certificado de Telemetria',
};

function certNextDate_(raw) {
  const m = String(raw || '').trim().match(/^(\d{1,2})\/(\d{1,2})\/(\d{4})$/);
  if (!m) return '';
  const d = Number(m[1]);
  const mo = Number(m[2]);
  var y = Number(m[3]) + 1;
  var day = d;
  if (mo === 2 && d === 29) day = 28;
  return ('0' + day).slice(-2) + '/' + ('0' + mo).slice(-2) + '/' + y;
}

/**
 * Página pública do QR do adesivo. Exige número + id do certificado
 * (ou id da OS nos adesivos antigos) para não permitir varrer certificados.
 */
function certPublic_(ss, p) {
  const number = String(p.n || p.cert || p.number || '').trim().toUpperCase();
  const id = String(p.id || p.k || '').trim();
  const osId = String(p.osId || p.os || '').trim();
  if (!id && !(number && osId)) {
    return json_({ ok: false, error: 'Link do certificado incompleto.' });
  }
  const tombstones = readCalibTombstones_(ss) || [];
  const sheet = ensureCalibsSheet_(ss);
  const data = sheet.getDataRange().getValues();
  var byId = null;
  var byOs = null;
  for (var i = 1; i < data.length; i++) {
    const rowId = String(data[i][0] || '').trim();
    const sameNumber = String(data[i][1] || '').trim().toUpperCase() === number;
    if (!(id && rowId === id) && !sameNumber) continue;
    if (tombstones.indexOf(rowId) >= 0) continue;
    if (id && rowId === id) {
      byId = data[i][4];
      break;
    }
    if (!byOs && osId) {
      const light = readOrderRecord_(data[i][4]);
      if (light && String(light.osId || '').trim() === osId) byOs = data[i][4];
    }
  }
  const raw = byId || byOs;
  if (!raw) {
    return json_({ ok: false, error: 'Certificado não encontrado.' });
  }
  const rec = readOrderRecord_(raw, { forceFull: true }) || {};
  const s = function (v) {
    return v === null || v === undefined ? '' : String(v).trim();
  };
  const kind = s(rec.kind) || 'volumetric';
  const standards = (rec.standards || [])
    .filter(function (x) {
      return x && (s(x.tag) || s(x.description) || s(x.certificate));
    })
    .map(function (x) {
      return {
        tag: s(x.tag),
        description: s(x.description),
        serialNumber: s(x.serialNumber),
        certificate: s(x.certificate),
        validity: s(x.validity),
        uncertainty: s(x.uncertainty),
      };
    });
  const isVolumetric = kind === 'volumetric' || kind === 'volumetricInverted';
  return json_({
    ok: true,
    certificate: {
      number: s(rec.number),
      kind: kind,
      kindLabel: CERT_KIND_LABELS_[kind] || 'Certificado de Calibração',
      issued: s(rec.status) === 'done',
      clientName: s(rec.clientName),
      site: s(rec.site),
      serviceRequester: s(rec.serviceRequester),
      osNumber: s(rec.osNumber),
      installLocation: s(rec.installLocation),
      systemType: s(rec.systemType),
      systemTag: s(rec.systemTag),
      equipmentTag: s(rec.equipmentTag),
      equipmentType: s(rec.equipmentType),
      manufacturer: s(rec.manufacturer),
      model: s(rec.model),
      serialNumber: s(rec.serialNumber),
      workingPrinciple: s(rec.workingPrinciple),
      fluid: s(rec.fluid),
      procedure: s(rec.procedure),
      calibrationDate: s(rec.calibrationDate),
      nextCalibrationDate: certNextDate_(rec.calibrationDate),
      technicianName: s(rec.technicianName),
      kFactorFound: isVolumetric ? s(rec.meterKFactorFound) : '',
      kFactorLeft: isVolumetric ? s(rec.meterKFactorLeft) : '',
      standards: standards,
    },
  });
}

function listCalibs_(ss) {
  return json_({
    ok: true,
    calibrations: readCalibs_(ss),
    deletedCalibrationIds: readCalibTombstones_(ss),
  });
}

/** Uma calibração completa (lê Drive se o JSON estiver offloaded). */
function getCalib_(ss, p) {
  const id = String(p.id || '').trim();
  const number = String(p.n || p.number || p.cert || '')
    .trim()
    .toUpperCase();
  if (!id && !number) {
    return json_({ ok: false, error: 'Calibração sem id' });
  }
  const tombstones = readCalibTombstones_(ss) || [];
  const sheet = ensureCalibsSheet_(ss);
  const data = sheet.getDataRange().getValues();
  for (var i = 1; i < data.length; i++) {
    const rowId = String(data[i][0] || '').trim();
    const rowNum = String(data[i][1] || '').trim().toUpperCase();
    if (tombstones.indexOf(rowId) >= 0) continue;
    if ((id && rowId === id) || (number && rowNum === number)) {
      const rec = readOrderRecord_(data[i][4], { forceFull: true });
      if (!rec || typeof rec !== 'object') {
        return json_({ ok: false, error: 'Certificado não encontrado.' });
      }
      if (!rec.id) rec.id = rowId;
      if (!rec.number) rec.number = data[i][1];
      return json_({ ok: true, calibration: rec });
    }
  }
  return json_({ ok: false, error: 'Certificado não encontrado.' });
}

const FLUID_HEADERS = ['id', 'name', 'density', 'viscosity', 'json', 'atualizado_em'];

function ensureFluidsSheet_(ss) {
  var sheet = ss.getSheetByName('fluidos');
  if (!sheet) {
    sheet = ss.insertSheet('fluidos');
    sheet.appendRow(FLUID_HEADERS);
  }
  return sheet;
}

function saveFluid_(ss, p) {
  const extra = parseJsonObject_(p.payload || p.json);
  const id = String(p.id || extra.id || '').trim();
  if (!id) return json_({ ok: false, error: 'Fluido sem id' });
  const record = Object.assign({}, extra, {
    id: id,
    name: String(p.name || extra.name || ''),
    densityMin: String(p.densityMin || extra.densityMin || ''),
    densityMax: String(p.densityMax || extra.densityMax || ''),
    viscosityMin: String(p.viscosityMin || extra.viscosityMin || ''),
    viscosityMax: String(p.viscosityMax || extra.viscosityMax || ''),
    densityRefTemp: String(p.densityRefTemp || extra.densityRefTemp || '20 °C'),
    viscosityRefTemp: String(p.viscosityRefTemp || extra.viscosityRefTemp || '40 °C'),
    updatedAt: String(p.updatedAt || extra.updatedAt || new Date().toISOString()),
  });
  const sheet = ensureFluidsSheet_(ss);
  const data = sheet.getDataRange().getValues();
  var row = -1;
  for (var i = 1; i < data.length; i++) {
    if (String(data[i][0]) === id) {
      row = i + 1;
      break;
    }
  }
  const json = JSON.stringify(record);
  const now = new Date();
  const dRange = (record.densityMin || record.densityMax) ? (record.densityMin + ' a ' + record.densityMax) : '';
  const vRange = (record.viscosityMin || record.viscosityMax) ? (record.viscosityMin + ' a ' + record.viscosityMax) : '';
  if (row < 0) {
    sheet.appendRow([id, record.name, dRange, vRange, json, now]);
  } else {
    sheet.getRange(row, 1, 1, 6).setValues([
      [id, record.name, dRange, vRange, json, now],
    ]);
  }
  return json_({ ok: true, id: id });
}

function readFluids_(ss) {
  const sheet = ensureFluidsSheet_(ss);
  const data = sheet.getDataRange().getValues();
  const list = [];
  for (var i = 1; i < data.length; i++) {
    const raw = data[i][4];
    try {
      if (typeof raw === 'string' && raw.charAt(0) === '{') {
        list.push(JSON.parse(raw));
      }
    } catch (error) {}
  }
  return list;
}

function listFluids_(ss) {
  return json_({ ok: true, fluids: readFluids_(ss) });
}

function deleteFluid_(ss, p) {
  const id = String(p.id || '').trim();
  if (!id) return json_({ ok: false, error: 'Fluido sem id' });
  const sheet = ensureFluidsSheet_(ss);
  const data = sheet.getDataRange().getValues();
  for (var i = 1; i < data.length; i++) {
    if (String(data[i][0]) === id) {
      sheet.deleteRow(i + 1);
      return json_({ ok: true, id: id });
    }
  }
  return json_({ ok: true, id: id });
}

function ensureCalibTombstones_(ss) {
  var sheet = ss.getSheetByName('calib_excluidos');
  if (!sheet) {
    sheet = ss.insertSheet('calib_excluidos');
    sheet.appendRow(['id', 'numero', 'excluido_em']);
  }
  return sheet;
}

/** Ids de certificados excluídos — nunca podem voltar por sync de cache antigo. */
function readCalibTombstones_(ss) {
  const sheet = ensureCalibTombstones_(ss);
  const data = sheet.getDataRange().getValues();
  const out = [];
  for (var i = 1; i < data.length; i++) {
    const id = String(data[i][0] || '').trim();
    if (id) out.push(id);
  }
  return out;
}

function deleteCalib_(ss, p) {
  const id = String(p.id || '').trim();
  if (!id) return json_({ ok: false, error: 'Calibração sem id' });
  const sheet = ensureCalibsSheet_(ss);
  const data = sheet.getDataRange().getValues();
  var number = String(p.number || '');
  for (var i = data.length - 1; i >= 1; i--) {
    if (String(data[i][0]) === id) {
      number = number || String(data[i][1] || '');
      sheet.deleteRow(i + 1);
    }
  }
  if (readCalibTombstones_(ss).indexOf(id) < 0) {
    ensureCalibTombstones_(ss).appendRow([id, number, new Date()]);
  }
  return json_({ ok: true, id: id });
}

function snapshot_(ss, p) {
  return json_({
    ok: true,
    users: hasToken_(p) ? publicUsers_(ss) : [],
    orders: readOrders_(ss),
    clients: readClients_(ss),
    standards: readStandards_(ss),
    calibrations: readCalibs_(ss),
    deletedCalibrationIds: readCalibTombstones_(ss),
    fluids: readFluids_(ss),
  });
}

function authorizeMail() {
  return MailApp.getRemainingDailyQuota();
}

/**
 * Rode esta função no editor (▶️) e aceite as permissões do Drive.
 * Grava PDF/foto de RH na pasta GS Campo - RH Documentos.
 * Depois: Implantar → Gerenciar implantações → lápis → Nova versão.
 */
function authorizeStaffDocs() {
  staffDocsFolder_();
  MailApp.getRemainingDailyQuota();
  return 'RH documentos: Drive e e-mail OK. Publique Nova versão.';
}

/**
 * Rode esta função no editor (▶️) e aceite as permissões do Drive.
 * Necessário para cadastros grandes de clientes (planilha Excel da adm).
 * Depois: Implantar → Gerenciar implantações → lápis → Nova versão.
 */
function authorizeClientPayloads() {
  clientPayloadFolder_();
  orderPayloadFolder_();
  const calibName = 'GS Campo - Calibracoes JSON';
  const calibFolders = DriveApp.getFoldersByName(calibName);
  if (!calibFolders.hasNext()) DriveApp.createFolder(calibName);
  return 'Clientes/OS/Calibrações JSON no Drive OK. Publique Nova versão.';
}

/**
 * Rode esta função no editor (▶️) com a conta dona da pasta de arquivos.
 * Confere o acesso à pasta das OS no Google Drive e apaga a sessão antiga
 * do OneDrive guardada nas propriedades.
 * Depois: Implantar → Gerenciar implantações → lápis → Nova versão.
 */
function authorizeDriveFiles() {
  // Força o diálogo de autorização com script.external_request (UrlFetchApp).
  try {
    UrlFetchApp.fetch(
      'https://www.googleapis.com/drive/v3/about?fields=user(emailAddress)',
      {
        method: 'get',
        headers: { Authorization: 'Bearer ' + ScriptApp.getOAuthToken() },
        muteHttpExceptions: true,
      },
    );
  } catch (error) {}
  const root = filesRoot_();
  const props = PropertiesService.getScriptProperties();
  Object.keys(props.getProperties()).forEach(function (key) {
    if (key.indexOf('ONEDRIVE_') === 0) props.deleteProperty(key);
  });
  return (
    'Pasta de arquivos OK: ' +
    root.getName() +
    '. Aceite as permissões (incluindo pedido externo) e publique Nova versão.'
  );
}

/**
 * AUTOMATIZAR DONO → administrativo@
 *
 * 1) No projeto Apps Script ainda do DONO ATUAL (ex.: Gmail pessoal), cole este
 *    código, autorize de novo se pedir Drive, e rode (▶️):
 *      transferOsDriveToAdministrativo
 *    Se a execução parar por tempo, rode de novo (continua de onde parou):
 *      continueTransferOsDriveToAdministrativo
 *
 * 2) No Gmail de administrativo@, aceite os convites de propriedade
 *    (ou rode, já logado como administrativo@ neste projeto compartilhado):
 *      acceptPendingOsDriveOwnership
 *
 * 3) Depois publique o login_gate.gs implantado como administrativo@
 *    (dono único do script — senão arquivos NOVOS continuam no Gmail).
 *
 * Relatório rápido: statusTransferOsDriveToAdministrativo
 */
var TRANSFER_STATE_KEY_ = 'GS_DRIVE_TRANSFER_STATE';
var TRANSFER_TIME_BUDGET_MS_ = 4.5 * 60 * 1000;

function transferOsDriveToAdministrativo() {
  PropertiesService.getScriptProperties().deleteProperty(TRANSFER_STATE_KEY_);
  return continueTransferOsDriveToAdministrativo();
}

function continueTransferOsDriveToAdministrativo() {
  const office = OFFICE_DRIVE_ACCOUNT_.toLowerCase();
  var me = driveScriptAccount_();
  // Mesmo sem e-mail na Session, a API Drive marca owners.me — dá para transferir.
  if (me === office) {
    return (
      'Esta execução já é como ' +
      office +
      '. Nada a transferir daqui. ' +
      'Se ainda houver arquivos do Gmail antigo, rode transferOsDriveToAdministrativo ' +
      'no projeto Apps Script da conta que ainda é dona desses arquivos.'
    );
  }

  const root = filesRoot_();
  if (!me) {
    try {
      const owner = root.getOwner();
      if (owner) {
        me = String(owner.getEmail() || '')
          .trim()
          .toLowerCase();
      }
    } catch (error) {}
  }
  const props = PropertiesService.getScriptProperties();
  var state = {};
  try {
    state = JSON.parse(props.getProperty(TRANSFER_STATE_KEY_) || '{}') || {};
  } catch (error) {
    state = {};
  }
  if (!state.queue || !state.queue.length) {
    state = {
      queue: [root.getId()],
      seen: {},
      transferred: 0,
      pending: 0,
      skipped: 0,
      errors: 0,
      errorSamples: [],
      startedAt: new Date().toISOString(),
      runnerEmail: me || '',
    };
    state.seen[root.getId()] = true;
  }

  const started = Date.now();
  while (state.queue.length && Date.now() - started < TRANSFER_TIME_BUDGET_MS_) {
    const id = state.queue.shift();
    try {
      const meta = driveGetFileMeta_(id);
      if (!meta) {
        state.skipped++;
        continue;
      }
      const mime = String(meta.mimeType || '');
      const isFolder = mime === 'application/vnd.google-apps.folder';
      if (isFolder) {
        const children = driveListChildrenIds_(id);
        for (var i = 0; i < children.length; i++) {
          const childId = children[i];
          if (state.seen[childId]) continue;
          state.seen[childId] = true;
          state.queue.push(childId);
        }
      }
      const owners = meta.owners || [];
      var ownedByMe = false;
      var ownedByOffice = false;
      for (var o = 0; o < owners.length; o++) {
        const owner = owners[o] || {};
        const mail = String(owner.emailAddress || '')
          .trim()
          .toLowerCase();
        if (owner.me === true) ownedByMe = true;
        if (me && mail === me) ownedByMe = true;
        if (mail === office) ownedByOffice = true;
      }
      if (ownedByOffice) {
        state.skipped++;
        continue;
      }
      if (!ownedByMe) {
        state.skipped++;
        continue;
      }
      if (!me && owners.length) {
        me = String(owners[0].emailAddress || '')
          .trim()
          .toLowerCase();
        state.runnerEmail = me;
      }
      const result = driveTransferOwnership_(id, office);
      if (result === 'ok') state.transferred++;
      else if (result === 'pending') state.pending++;
      else {
        state.errors++;
        if (state.errorSamples.length < 8) {
          state.errorSamples.push(meta.name + ': ' + result);
        }
      }
    } catch (error) {
      state.errors++;
      if (state.errorSamples.length < 8) {
        state.errorSamples.push(String((error && error.message) || error));
      }
    }
  }

  const done = state.queue.length === 0;
  if (done) props.deleteProperty(TRANSFER_STATE_KEY_);
  else props.setProperty(TRANSFER_STATE_KEY_, JSON.stringify(state));

  const runner = me || state.runnerEmail || '(conta atual do editor)';
  const lines = [
    done ? 'Transferência concluída (nesta conta).' : 'Parcial — rode continueTransferOsDriveToAdministrativo de novo.',
    'Conta que transferiu: ' + runner,
    'Novo dono: ' + office,
    'Transferidos agora/total sessão: ' + state.transferred,
    'Aguardando aceite (pending): ' + state.pending,
    'Já eram do escritório / outros: ' + state.skipped,
    'Erros: ' + state.errors,
    'Fila restante: ' + state.queue.length,
  ];
  if (state.errorSamples.length) {
    lines.push('Exemplos: ' + state.errorSamples.join(' | '));
  }
  if (state.pending > 0 || done) {
    lines.push(
      'Próximo: entre como ' +
        office +
        ' e rode acceptPendingOsDriveOwnership (ou aceite os e-mails do Drive).',
    );
  }
  return lines.join('\n');
}

function statusTransferOsDriveToAdministrativo() {
  const raw = PropertiesService.getScriptProperties().getProperty(
    TRANSFER_STATE_KEY_,
  );
  if (!raw) {
    return 'Nenhuma transferência em andamento. Rode transferOsDriveToAdministrativo.';
  }
  return raw;
}

var ACCEPT_STATE_KEY_ = 'GS_DRIVE_ACCEPT_STATE';

/**
 * Rode logado como administrativo@ (projeto compartilhado ou cópia na conta).
 * Aceita propriedade pendente na pasta das OS + itens "Compartilhados comigo".
 * Se parar no meio: continueAcceptPendingOsDriveOwnership.
 */
function acceptPendingOsDriveOwnership() {
  PropertiesService.getScriptProperties().deleteProperty(ACCEPT_STATE_KEY_);
  return continueAcceptPendingOsDriveOwnership();
}

function continueAcceptPendingOsDriveOwnership() {
  const office = OFFICE_DRIVE_ACCOUNT_.toLowerCase();
  const me = driveScriptAccount_();
  if (me && me !== office) {
    throw new Error(
      'Rode acceptPendingOsDriveOwnership logado como ' +
        office +
        ' (agora está como ' +
        me +
        ').',
    );
  }
  const token = ScriptApp.getOAuthToken();
  const props = PropertiesService.getScriptProperties();
  var state = {};
  try {
    state = JSON.parse(props.getProperty(ACCEPT_STATE_KEY_) || '{}') || {};
  } catch (error) {
    state = {};
  }
  if (!state.queue || !state.queue.length) {
    const seed = {};
    seed[filesFolderId_()] = true;
    const shared = driveListSharedWithMeIds_();
    for (var s = 0; s < shared.length; s++) seed[shared[s]] = true;
    state = {
      queue: Object.keys(seed),
      seen: seed,
      accepted: 0,
      already: 0,
      errors: 0,
      errorSamples: [],
      startedAt: new Date().toISOString(),
    };
  }

  const started = Date.now();
  while (state.queue.length && Date.now() - started < TRANSFER_TIME_BUDGET_MS_) {
    const id = state.queue.shift();
    try {
      const meta = driveGetFileMeta_(id);
      if (!meta) {
        state.already++;
        continue;
      }
      if (String(meta.mimeType || '') === 'application/vnd.google-apps.folder') {
        const children = driveListChildrenIds_(id);
        for (var i = 0; i < children.length; i++) {
          const childId = children[i];
          if (state.seen[childId]) continue;
          state.seen[childId] = true;
          state.queue.push(childId);
        }
      }
      const owners = meta.owners || [];
      var alreadyMine = false;
      for (var o = 0; o < owners.length; o++) {
        const mail = String((owners[o] && owners[o].emailAddress) || '')
          .trim()
          .toLowerCase();
        if (owners[o].me === true || mail === office || (me && mail === me)) {
          alreadyMine = true;
          break;
        }
      }
      if (alreadyMine) {
        state.already++;
        continue;
      }
      const ok = driveAcceptPendingOwnership_(id, token);
      if (ok) state.accepted++;
      else {
        state.errors++;
        if (state.errorSamples.length < 8) {
          state.errorSamples.push(meta.name || id);
        }
      }
    } catch (error) {
      state.errors++;
      if (state.errorSamples.length < 8) {
        state.errorSamples.push(String((error && error.message) || error));
      }
    }
  }

  const done = state.queue.length === 0;
  if (done) props.deleteProperty(ACCEPT_STATE_KEY_);
  else props.setProperty(ACCEPT_STATE_KEY_, JSON.stringify(state));

  var rootNote = '';
  try {
    const root = filesRoot_();
    const owner = root.getOwner();
    const ownerMail = owner
      ? String(owner.getEmail() || '')
          .trim()
          .toLowerCase()
      : '';
    rootNote =
      ownerMail === office
        ? 'Pasta raiz das OS: dono = ' + office + '.'
        : 'Pasta raiz das OS ainda com dono: ' +
          (ownerMail || '?') +
          '. Se houver e-mail/convite do Drive, aceite também pela interface.';
  } catch (error) {
    rootNote = String((error && error.message) || error);
  }

  const lines = [
    done
      ? 'Aceite concluído.'
      : 'Parcial — rode continueAcceptPendingOsDriveOwnership de novo.',
    'Aceites nesta sessão: ' + state.accepted,
    'Já eram seus / sem pendência: ' + state.already,
    'Falhas: ' + state.errors,
    'Fila restante: ' + state.queue.length,
    rootNote,
  ];
  if (state.errorSamples.length) {
    lines.push('Exemplos: ' + state.errorSamples.join(' | '));
  }
  return lines.join('\n');
}

/** Itens em "Compartilhados comigo" (onde costuma cair o convite de dono). */
function driveListSharedWithMeIds_() {
  const token = ScriptApp.getOAuthToken();
  var pageToken = '';
  const out = [];
  do {
    var url =
      'https://www.googleapis.com/drive/v3/files?q=' +
      encodeURIComponent('sharedWithMe = true and trashed = false') +
      '&fields=nextPageToken,files(id)&pageSize=100&supportsAllDrives=true';
    if (pageToken) url += '&pageToken=' + encodeURIComponent(pageToken);
    const res = UrlFetchApp.fetch(url, {
      method: 'get',
      headers: { Authorization: 'Bearer ' + token },
      muteHttpExceptions: true,
    });
    if (res.getResponseCode() < 200 || res.getResponseCode() >= 300) break;
    const json = JSON.parse(res.getContentText() || '{}');
    const files = json.files || [];
    for (var i = 0; i < files.length; i++) out.push(files[i].id);
    pageToken = json.nextPageToken || '';
  } while (pageToken);
  return out;
}

function driveGetFileMeta_(fileId) {
  const res = UrlFetchApp.fetch(
    'https://www.googleapis.com/drive/v3/files/' +
      encodeURIComponent(fileId) +
      '?fields=id,name,mimeType,owners(emailAddress,me)&supportsAllDrives=true',
    {
      method: 'get',
      headers: { Authorization: 'Bearer ' + ScriptApp.getOAuthToken() },
      muteHttpExceptions: true,
    },
  );
  if (res.getResponseCode() < 200 || res.getResponseCode() >= 300) return null;
  return JSON.parse(res.getContentText() || '{}');
}

function driveListChildrenIds_(folderId) {
  const token = ScriptApp.getOAuthToken();
  var pageToken = '';
  const out = [];
  do {
    var url =
      'https://www.googleapis.com/drive/v3/files?q=' +
      encodeURIComponent('"' + folderId + '" in parents and trashed = false') +
      '&fields=nextPageToken,files(id)&pageSize=200&supportsAllDrives=true&includeItemsFromAllDrives=true';
    if (pageToken) url += '&pageToken=' + encodeURIComponent(pageToken);
    const res = UrlFetchApp.fetch(url, {
      method: 'get',
      headers: { Authorization: 'Bearer ' + token },
      muteHttpExceptions: true,
    });
    if (res.getResponseCode() < 200 || res.getResponseCode() >= 300) break;
    const json = JSON.parse(res.getContentText() || '{}');
    const files = json.files || [];
    for (var i = 0; i < files.length; i++) out.push(files[i].id);
    pageToken = json.nextPageToken || '';
  } while (pageToken);
  return out;
}

/**
 * Transfere propriedade para o escritório.
 * Retorna: 'ok' | 'pending' | mensagem de erro.
 */
function driveTransferOwnership_(fileId, officeEmail) {
  const token = ScriptApp.getOAuthToken();
  // Garante editor antes (alguns casos a API exige).
  try {
    UrlFetchApp.fetch(
      'https://www.googleapis.com/drive/v3/files/' +
        encodeURIComponent(fileId) +
        '/permissions?sendNotificationEmail=false&supportsAllDrives=true',
      {
        method: 'post',
        contentType: 'application/json',
        headers: { Authorization: 'Bearer ' + token },
        payload: JSON.stringify({
          role: 'writer',
          type: 'user',
          emailAddress: officeEmail,
        }),
        muteHttpExceptions: true,
      },
    );
  } catch (error) {}

  const res = UrlFetchApp.fetch(
    'https://www.googleapis.com/drive/v3/files/' +
      encodeURIComponent(fileId) +
      '/permissions?transferOwnership=true&sendNotificationEmail=true&supportsAllDrives=true',
    {
      method: 'post',
      contentType: 'application/json',
      headers: { Authorization: 'Bearer ' + token },
      payload: JSON.stringify({
        role: 'owner',
        type: 'user',
        emailAddress: officeEmail,
      }),
      muteHttpExceptions: true,
    },
  );
  const code = res.getResponseCode();
  const body = String(res.getContentText() || '');
  if (code >= 200 && code < 300) {
    if (/pendingOwner|pending/i.test(body)) return 'pending';
    return 'ok';
  }
  // Já é dono / convite já existe.
  if (
    code === 400 &&
    /already|pending|owner/i.test(body)
  ) {
    return /pending/i.test(body) ? 'pending' : 'ok';
  }
  return 'HTTP ' + code + ' ' + body.slice(0, 180);
}

function driveAcceptPendingOwnership_(fileId, token) {
  const list = UrlFetchApp.fetch(
    'https://www.googleapis.com/drive/v3/files/' +
      encodeURIComponent(fileId) +
      '/permissions?fields=permissions(id,emailAddress,role,pendingOwner)&supportsAllDrives=true',
    {
      method: 'get',
      headers: { Authorization: 'Bearer ' + token },
      muteHttpExceptions: true,
    },
  );
  if (list.getResponseCode() < 200 || list.getResponseCode() >= 300) return false;
  const me = driveScriptAccount_();
  const permissions = (JSON.parse(list.getContentText() || '{}').permissions) || [];
  var permId = '';
  for (var i = 0; i < permissions.length; i++) {
    const p = permissions[i];
    const mail = String(p.emailAddress || '')
      .trim()
      .toLowerCase();
    if (p.pendingOwner && (!me || mail === me || mail === OFFICE_DRIVE_ACCOUNT_.toLowerCase())) {
      permId = p.id;
      break;
    }
  }
  if (!permId) {
    // Tenta recriar como owner (alguns convites só fecham no PATCH genérico).
    const create = UrlFetchApp.fetch(
      'https://www.googleapis.com/drive/v3/files/' +
        encodeURIComponent(fileId) +
        '/permissions?transferOwnership=true&supportsAllDrives=true',
      {
        method: 'post',
        contentType: 'application/json',
        headers: { Authorization: 'Bearer ' + token },
        payload: JSON.stringify({
          role: 'owner',
          type: 'user',
          emailAddress: OFFICE_DRIVE_ACCOUNT_,
        }),
        muteHttpExceptions: true,
      },
    );
    return create.getResponseCode() >= 200 && create.getResponseCode() < 300;
  }
  const patch = UrlFetchApp.fetch(
    'https://www.googleapis.com/drive/v3/files/' +
      encodeURIComponent(fileId) +
      '/permissions/' +
      encodeURIComponent(permId) +
      '?transferOwnership=true&supportsAllDrives=true',
    {
      method: 'patch',
      contentType: 'application/json',
      headers: { Authorization: 'Bearer ' + token },
      payload: JSON.stringify({ role: 'owner' }),
      muteHttpExceptions: true,
    },
  );
  return patch.getResponseCode() >= 200 && patch.getResponseCode() < 300;
}

function extraEmails_(raw) {
  const set = {};
  var list = [];
  if (Array.isArray(raw)) list = raw;
  else list = String(raw || '').split(/[;,]/);
  list.forEach(function (item) {
    const email = String(item || '')
      .trim()
      .toLowerCase();
    if (email.indexOf('@') > 0) set[email] = true;
  });
  return Object.keys(set);
}

function sendMail_(ss, p) {
  logMail_(p.osId, { ok: false, pending: true });
  var toList = extraEmails_(p.to);
  if (!toList.length) toList = officeEmails_(ss);
  extraEmails_(p.extraTo).forEach(function (email) {
    if (toList.indexOf(email) < 0) toList.push(email);
  });
  const ccList = extraEmails_(p.cc).filter(function (email) {
    return toList.indexOf(email) < 0;
  });
  const to = toList.join(', ');
  const subject = String(p.subject || '').slice(0, 200);
  const body = String(p.body || '').slice(0, 12000);
  const replyTo = String(p.replyTo || '').trim();
  const files = Array.isArray(p.files) ? p.files : parseJson_(p.filesJson, []);
  const blobs = [];
  var total = 0;
  // Gmail/MailApp aguenta ~25 MB; mantém folga. ZIP de RDOs entra como 1 anexo.
  const maxBytes = 22 * 1024 * 1024;
  const maxFiles = 40;
  for (var i = 0; i < files.length && i < maxFiles; i++) {
    const item = files[i] || {};
    var raw = String(item.data || item.base64 || '').replace(/\s/g, '');
    const marker = 'base64,';
    const cut = raw.indexOf(marker);
    if (cut >= 0) raw = raw.slice(cut + marker.length);
    if (!raw) continue;
    var bytes;
    try {
      bytes = Utilities.base64Decode(raw);
    } catch (error) {
      continue;
    }
    total += bytes.length;
    if (total > maxBytes) break;
    const name = String(item.name || ('anexo_' + (i + 1))).slice(0, 120);
    const mime = String(item.mime || mimeFromName_(name));
    blobs.push(Utilities.newBlob(bytes, mime, name));
  }
  if (!subject || !body) {
    logMail_(p.osId, { ok: false, error: 'E-mail sem assunto ou texto' });
    return json_({ ok: false, error: 'E-mail sem assunto ou texto' });
  }
  if (files.length && !blobs.length) {
    logMail_(p.osId, { ok: false, error: 'Anexos inválidos' });
    return json_({
      ok: false,
      error: 'Os PDFs não chegaram no e-mail. Atualize o script e tente de novo.',
    });
  }
  try {
    const options = { to: to, subject: subject, body: body, name: 'GS Campo' };
    if (ccList.length) options.cc = ccList.join(', ');
    if (blobs.length) options.attachments = blobs;
    if (replyTo && replyTo.indexOf('@') > 0) options.replyTo = replyTo;
    MailApp.sendEmail(options);
    logMail_(p.osId, { ok: true, sent: true, files: blobs.length, to: to });
    return json_({
      ok: true,
      sent: true,
      files: blobs.length,
      to: to,
      cc: ccList.join(', '),
    });
  } catch (error) {
    const message = 'Não foi possível enviar o e-mail. ' + error;
    logMail_(p.osId, { ok: false, error: String(error) });
    return json_({ ok: false, error: message });
  }
}

function mailStatus_(p) {
  const osId = String(p.osId || '').trim();
  if (!osId) return json_({ ok: false, error: 'OS sem id' });
  try {
    const raw = PropertiesService.getScriptProperties().getProperty(
      'mail_' + osId.slice(0, 80),
    );
    if (!raw) return json_({ ok: false, pending: true });
    const data = JSON.parse(raw);
    if (data.pending === true && data.ok !== true) {
      return json_({ ok: false, pending: true });
    }
    if (data.ok === true) {
      return json_({ ok: true, sent: true, files: data.files || 0 });
    }
    return json_({ ok: false, error: String(data.error || 'Falha no e-mail') });
  } catch (error) {
    return json_({ ok: false, pending: true });
  }
}

function logMail_(osId, payload) {
  try {
    PropertiesService.getScriptProperties().setProperty(
      'mail_' + String(osId || 'x').slice(0, 80),
      JSON.stringify(Object.assign({ at: Date.now() }, payload)),
    );
  } catch (error) {}
}

function mimeFromName_(name) {
  const lower = String(name || '').toLowerCase();
  if (lower.slice(-4) === '.pdf') return 'application/pdf';
  if (lower.slice(-4) === '.zip') return 'application/zip';
  if (lower.slice(-4) === '.png') return 'image/png';
  if (lower.slice(-4) === '.jpg' || lower.slice(-5) === '.jpeg') {
    return 'image/jpeg';
  }
  if (lower.slice(-5) === '.webp') return 'image/webp';
  if (lower.slice(-5) === '.heic') return 'image/heic';
  if (lower.slice(-5) === '.xlsx') {
    return 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet';
  }
  if (lower.slice(-5) === '.xlsm') {
    return 'application/vnd.ms-excel.sheet.macroEnabled.12';
  }
  if (lower.slice(-4) === '.xls') return 'application/vnd.ms-excel';
  return 'application/octet-stream';
}

function officeEmails_(ss) {
  const set = {};
  function add(raw) {
    const email = String(raw || '')
      .trim()
      .toLowerCase();
    if (email.indexOf('@') > 0) set[email] = true;
  }
  add('administrativo@gssolucoestec.com.br');
  add('amanda@gssolucoestec.com.br');
  const sheet = ss.getSheetByName('usuarios');
  readUsers_(sheet).forEach(function (user) {
    if (user.status !== 'aprovado' || !user.active) return;
    if (user.role === 'admin' || user.role === 'ambos') add(user.email);
  });
  return Object.keys(set);
}

function newSignToken_() {
  return (
    Utilities.getUuid().replace(/-/g, '') +
    Utilities.getUuid().replace(/-/g, '').slice(0, 8)
  );
}

function findRdoByToken_(ss, token) {
  const wanted = String(token || '').trim();
  if (!wanted) return null;
  const orders = readOrders_(ss);
  for (var i = 0; i < orders.length; i++) {
    const rdos = orders[i].rdos || [];
    for (var j = 0; j < rdos.length; j++) {
      if (String(rdos[j].signToken || '') === wanted) {
        return { order: orders[i], rdo: rdos[j] };
      }
    }
  }
  return null;
}

function escapeHtml_(value) {
  return String(value || '')
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;');
}

function formatRdoDay_(raw) {
  const parsed = new Date(raw);
  if (isNaN(parsed.getTime())) return String(raw || '');
  const d = parsed.getDate().toString().padStart(2, '0');
  const m = (parsed.getMonth() + 1).toString().padStart(2, '0');
  return d + '/' + m + '/' + parsed.getFullYear();
}

function signRequest_(ss, p) {
  const osId = String(p.osId || '').trim();
  const ids = String(p.rdoIds || '')
    .split(',')
    .map(function (item) {
      return String(item || '').trim();
    })
    .filter(function (item) {
      return item.length > 0;
    });
  const found = findOrder_(ss, osId);
  if (found.row < 0) return json_({ ok: false, error: 'OS não encontrada' });
  const record = found.record || {};
  const rdos = Array.isArray(record.rdos) ? record.rdos : [];
  const baseUrl = ScriptApp.getService().getUrl();
  const links = [];
  for (var i = 0; i < rdos.length; i++) {
    if (ids.length && ids.indexOf(String(rdos[i].id)) < 0) continue;
    if (!rdos[i].clientSignedName) {
      rdos[i].signToken = newSignToken_();
    }
    const token = String(rdos[i].signToken || '');
    if (!token) continue;
    links.push({
      id: rdos[i].id,
      date: formatRdoDay_(rdos[i].date),
      url: baseUrl + '?action=signpage&token=' + token,
      signed: !!rdos[i].clientSignedName,
    });
  }
  if (!links.length) {
    return json_({ ok: false, error: 'Nenhum RDO selecionado.' });
  }
  record.rdos = rdos;
  writeOrder_(found, record);
  const number = String(record.number || p.osNumber || '');
  const baseEmail =
    record.rdo && record.rdo.baseEmail ? String(record.rdo.baseEmail).trim() : '';
  const toSet = {};
  officeEmails_(ss).forEach(function (email) {
    toSet[email] = true;
  });
  if (baseEmail.indexOf('@') > 0) toSet[baseEmail.toLowerCase()] = true;
  const lines = links.map(function (item) {
    return (
      (item.signed ? 'Já assinado · ' : 'Assinar · ') +
      'RDO ' +
      item.date +
      '\n' +
      item.url
    );
  });
  const body =
    'Prezados,\n\n' +
    'Encaminho, para conhecimento e registro, o link de assinatura eletrônica do Relatório Diário de Obra (RDO) referente à Ordem de Serviço nº ' +
    number +
    ', executada pela GS Soluções Técnicas.\n\n' +
    lines.join('\n\n') +
    '\n\nQuando o responsável da base assinar, o RDO passa a constar no GS Campo com as duas assinaturas.\n\nFico à disposição para quaisquer esclarecimentos ou informações adicionais que sejam necessárias.\n\nAtenciosamente,\nGS Soluções Técnicas\n';
  try {
    MailApp.sendEmail({
      to: Object.keys(toSet).join(', '),
      subject: 'Assinatura do RDO da OS ' + number + ' — GS Soluções Técnicas',
      body: body,
      name: 'GS Campo',
    });
    return json_({ ok: true, sent: true, links: links.length });
  } catch (error) {
    return json_({
      ok: false,
      error: 'Não foi possível enviar o link. ' + error,
    });
  }
}

function signPage_(ss, p, message, done) {
  const token = String(p.token || '').trim();
  const found = findRdoByToken_(ss, token);
  const url = ScriptApp.getService().getUrl();
  if (!found) {
    return htmlPage_(
      'Link inválido',
      '<p>Este link de assinatura não é mais válido.</p>',
    );
  }
  const already = !!found.rdo.clientSignedName;
  const number = escapeHtml_(found.order.number || '');
  const day = escapeHtml_(formatRdoDay_(found.rdo.date));
  const baseName = escapeHtml_(
    (found.order.rdo && found.order.rdo.baseName) ||
      found.rdo.clientSignedName ||
      '',
  );
  const note = message
    ? '<p style="color:#8B2E2E">' + escapeHtml_(message) + '</p>'
    : '';
  if (already || done) {
    return htmlPage_(
      'RDO assinado',
      note +
        '<p>O RDO da OS ' +
        number +
        ' (' +
        day +
        ') já está assinado por <strong>' +
        escapeHtml_(found.rdo.clientSignedName || baseName) +
        '</strong>.</p><p>A GS Soluções foi avisada.</p>',
    );
  }
  const body =
    note +
    '<p>OS <strong>' +
    number +
    '</strong> · RDO de <strong>' +
    day +
    '</strong></p>' +
    '<form method="POST" action="' +
    escapeHtml_(url) +
    '">' +
    '<input type="hidden" name="action" value="clientsign">' +
    '<input type="hidden" name="token" value="' +
    escapeHtml_(token) +
    '">' +
    '<label>Nome de quem assina</label>' +
    '<input name="name" required value="' +
    baseName +
    '">' +
    '<button type="submit">Assinar eletronicamente</button>' +
    '</form>' +
    '<p class="muted">Assinado eletronicamente por nome, cargo da base, data e GS SOLUÇÕES LTDA. Cnpj: 64.949.495/0001-82.</p>';
  return htmlPage_('Assinar RDO', body);
}

function clientSign_(ss, p) {
  const token = String(p.token || '').trim();
  const name = String(p.name || p.signerName || '').trim().slice(0, 80);
  if (!token) return signPage_(ss, p, 'Link inválido.');
  if (!name) return signPage_(ss, p, 'Informe o nome para assinar.');
  const found = findRdoByToken_(ss, token);
  if (!found) return signPage_(ss, p, 'Este link não é mais válido.');
  if (found.rdo.clientSignedName) return signPage_(ss, p, '', true);
  const orderFound = findOrder_(ss, found.order.id);
  const record = orderFound.record || found.order;
  const rdos = Array.isArray(record.rdos) ? record.rdos : [];
  for (var i = 0; i < rdos.length; i++) {
    if (String(rdos[i].signToken || '') !== token) continue;
    rdos[i].clientSignedName = name;
    rdos[i].clientSignedAt = new Date().toISOString();
  }
  record.rdos = rdos;
  writeOrder_(orderFound, record);
  try {
    MailApp.sendEmail({
      to: officeEmails_(ss).join(', '),
      subject:
        'Cliente assinou o RDO da OS ' +
        (record.number || '') +
        ' — GS Soluções Técnicas',
      body:
        'O cliente ' +
        name +
        ' assinou o RDO da OS ' +
        (record.number || '') +
        '.\n\nO relatório já aparece no GS Campo assinado pelos dois.\n',
      name: 'GS Campo',
    });
  } catch (error) {}
  found.rdo.clientSignedName = name;
  return signPage_(ss, { token: token }, '', true);
}

function htmlPage_(title, inner) {
  const html =
    '<!DOCTYPE html><html lang="pt-BR"><head><meta charset="utf-8">' +
    '<meta name="viewport" content="width=device-width, initial-scale=1">' +
    '<title>' +
    escapeHtml_(title) +
    '</title><style>' +
    'body{font-family:Arial,sans-serif;background:#F4EFE4;color:#1A2330;margin:0;padding:24px}' +
    '.card{max-width:480px;margin:0 auto;background:#fff;padding:24px;border:2px solid #C6A03A}' +
    'h1{font-size:22px;margin:0 0 12px}p{line-height:1.45}' +
    'label{display:block;font-weight:700;margin:16px 0 6px}' +
    'input{width:100%;box-sizing:border-box;padding:12px;font-size:16px;border:1px solid #C6A03A}' +
    'button{margin-top:16px;width:100%;padding:14px;background:#1A2330;color:#fff;border:0;font-size:16px;font-weight:700}' +
    '.muted{color:#5C6570;font-size:13px}' +
    '</style></head><body><div class="card"><h1>' +
    escapeHtml_(title) +
    '</h1>' +
    inner +
    '</div></body></html>';
  return HtmlService.createHtmlOutput(html)
    .setTitle(title)
    .setXFrameOptionsMode(HtmlService.XFrameOptionsMode.ALLOWALL);
}

function json_(obj) {
  const text = JSON.stringify(obj);
  if (CALLBACK_) {
    return ContentService.createTextOutput(
      CALLBACK_ + '(' + text + ')',
    ).setMimeType(ContentService.MimeType.JAVASCRIPT);
  }
  return ContentService.createTextOutput(text).setMimeType(
    ContentService.MimeType.JSON,
  );
}

/** Pasta raiz dos arquivos das OS (RDO, fotos, anexos, certificados, RH). */
const DEFAULT_FILES_FOLDER_ID_ = '1VZHSOnhNrTgccGU-aRrTD4v3hriE2jnC';
/** Conta do Drive do escritório (não a conta pessoal de quem implantou o script). */
const OFFICE_DRIVE_ACCOUNT_ = 'administrativo@gssolucoestec.com.br';

function filesFolderId_() {
  const custom = PropertiesService.getScriptProperties().getProperty(
    'GS_FILES_FOLDER_ID',
  );
  return custom ? String(custom).trim() : DEFAULT_FILES_FOLDER_ID_;
}

function filesRoot_() {
  const id = filesFolderId_();
  var folder;
  try {
    folder = DriveApp.getFolderById(id);
  } catch (error) {
    throw new Error(
      'Sem acesso à pasta de arquivos no Google Drive (' +
        id +
        '). Compartilhe a pasta com a conta que implanta o script (' +
        OFFICE_DRIVE_ACCOUNT_ +
        ') com permissão de editar. Detalhe: ' +
        error,
    );
  }
  if (folder.isTrashed()) {
    throw new Error('A pasta de arquivos do Google Drive está na lixeira.');
  }
  return folder;
}

function driveStatus_(p) {
  try {
    const root = filesRoot_();
    const deployer = String(Session.getEffectiveUser().getEmail() || '')
      .trim()
      .toLowerCase();
    var folderOwner = '';
    try {
      const owner = root.getOwner();
      if (owner) {
        folderOwner = String(owner.getEmail() || '')
          .trim()
          .toLowerCase();
      }
    } catch (error) {}
    const office = OFFICE_DRIVE_ACCOUNT_.toLowerCase();
    const wrongDeployer = deployer && deployer !== office;
    const wrongFolderOwner = folderOwner && folderOwner !== office;
    return json_({
      ok: true,
      connected: true,
      folderUrl: root.getUrl(),
      account: OFFICE_DRIVE_ACCOUNT_,
      deployerEmail: deployer,
      folderOwnerEmail: folderOwner,
      wrongOwner: wrongDeployer || wrongFolderOwner,
      warning: wrongDeployer
        ? 'O Apps Script ainda está implantado como ' +
          deployer +
          '. Publique de novo logado em ' +
          OFFICE_DRIVE_ACCOUNT_ +
          ' (dono único do projeto).'
        : wrongFolderOwner
          ? 'A pasta das OS ainda tem dono ' +
            folderOwner +
            '. Transfira a propriedade para ' +
            OFFICE_DRIVE_ACCOUNT_ +
            '.'
          : '',
    });
  } catch (error) {
    return json_({
      ok: false,
      connected: false,
      error: String((error && error.message) || error),
    });
  }
}

function safeDriveName_(name, max) {
  return String(name || '')
    .replace(/[\\/:*?"<>|]/g, '-')
    .trim()
    .slice(0, max || 120);
}

function driveFindFolder_(parent, name) {
  const found = parent.getFoldersByName(name);
  while (found.hasNext()) {
    const folder = found.next();
    if (!folder.isTrashed()) return folder;
  }
  return null;
}

function driveChildFolder_(parent, name) {
  const safe = safeDriveName_(name, 120) || 'pasta';
  return driveFindFolder_(parent, safe) || parent.createFolder(safe);
}

function driveFindFiles_(folder, name) {
  const out = [];
  const found = folder.getFilesByName(name);
  while (found.hasNext()) {
    const file = found.next();
    if (!file.isTrashed()) out.push(file);
  }
  return out;
}

function osFolderKey_(number) {
  return String(number || 'OS')
    .trim()
    .replace(/\//g, '-')
    .replace(/[\\:*?"<>|]/g, '-')
    .slice(0, 80);
}

/** Pasta de destino dentro da OS: RDO, Fotos, Anexos, Certificados ou caminho "A/B". */
function osFolderLabel_(folderRaw) {
  const raw = String(folderRaw || 'Anexos').trim();
  if (raw.indexOf('/') >= 0 || raw.indexOf('\\') >= 0) return raw;
  const lower = raw.toLowerCase();
  if (lower.indexOf('rdo') >= 0) return 'RDO';
  if (lower.indexOf('foto') >= 0) return 'Fotos';
  if (lower.indexOf('cert') >= 0 || lower.indexOf('calib') >= 0) {
    return 'Certificados de Calibração';
  }
  return 'Anexos';
}

function osTargetFolder_(osFolder, label, cache, create) {
  if (Object.prototype.hasOwnProperty.call(cache, label)) return cache[label];
  const parts = label
    .split(/[\\/]/)
    .map(function (part) {
      return safeDriveName_(part, 120);
    })
    .filter(function (part) {
      return part.length > 0;
    });
  var current = osFolder;
  for (var i = 0; i < parts.length && current; i++) {
    current = create
      ? driveChildFolder_(current, parts[i])
      : driveFindFolder_(current, parts[i]);
  }
  cache[label] = current;
  return current;
}

function uniqueDriveName_(folder, name) {
  var base = name;
  var ext = '';
  const dot = name.lastIndexOf('.');
  if (dot > 0) {
    base = name.slice(0, dot);
    ext = name.slice(dot);
  }
  for (var n = 0; n < 40; n++) {
    const candidate =
      n === 0 ? name : base + '_copia' + (n === 1 ? '' : String(n)) + ext;
    if (driveFindFiles_(folder, candidate).length === 0) return candidate;
  }
  return base + '_' + Date.now() + ext;
}

function logOsFolder_(osId, payload) {
  try {
    PropertiesService.getScriptProperties().setProperty(
      'osfolder_' + String(osId || 'x').slice(0, 80),
      JSON.stringify(Object.assign({ at: Date.now() }, payload)),
    );
  } catch (error) {}
}

function osFolderStatus_(p) {
  const osId = String(p.osId || '').trim();
  if (!osId) return json_({ ok: false, error: 'OS sem id' });
  try {
    const raw = PropertiesService.getScriptProperties().getProperty(
      'osfolder_' + osId.slice(0, 80),
    );
    if (!raw) return json_({ ok: false, pending: true });
    const data = JSON.parse(raw);
    if (data.pending === true && data.ok !== true) {
      return json_({ ok: false, pending: true });
    }
    if (data.ok === true) {
      return json_({
        ok: true,
        sent: true,
        files: data.files || 0,
        folderUrl: data.folderUrl || '',
      });
    }
    return json_({
      ok: false,
      error: String(data.error || 'Falha ao salvar no Google Drive'),
    });
  } catch (error) {
    return json_({ ok: false, pending: true });
  }
}

function checkOsFolder_(p) {
  try {
    const osFolder = driveFindFolder_(
      filesRoot_(),
      osFolderKey_(p.osNumber),
    );
    const existing = [];
    if (!osFolder) return json_({ ok: true, existing: existing });
    const cache = {};
    const files = Array.isArray(p.files) ? p.files : [];
    for (var i = 0; i < files.length; i++) {
      const item = files[i] || {};
      const name = safeDriveName_(item.name, 120);
      if (!name) continue;
      const label = osFolderLabel_(item.folder);
      const target = osTargetFolder_(osFolder, label, cache, false);
      if (target && driveFindFiles_(target, name).length > 0) {
        existing.push(label + '/' + name);
      }
    }
    return json_({ ok: true, existing: existing });
  } catch (error) {
    return json_({ ok: false, error: String((error && error.message) || error) });
  }
}

/**
 * Lista arquivos da pasta da OS no Drive (RDO, certificados, book, fotos…).
 * Mesma árvore que o app grava via saveosfolder.
 */
function listOsDriveFilesRecursive_(folder, prefix, out, depth) {
  if (!folder || depth > 6 || out.length >= 400) return;
  const folders = folder.getFolders();
  while (folders.hasNext()) {
    const child = folders.next();
    if (child.isTrashed()) continue;
    const path = prefix ? prefix + '/' + child.getName() : child.getName();
    listOsDriveFilesRecursive_(child, path, out, depth + 1);
  }
  const files = folder.getFiles();
  while (files.hasNext()) {
    const file = files.next();
    if (file.isTrashed()) continue;
    var mime = '';
    try {
      mime = String(file.getMimeType() || '');
    } catch (error) {}
    out.push({
      id: file.getId(),
      name: file.getName(),
      path: prefix ? prefix + '/' + file.getName() : file.getName(),
      folder: prefix || '',
      mimeType: mime,
      url: file.getUrl(),
      downloadUrl:
        'https://drive.google.com/uc?export=download&id=' + file.getId(),
      updatedAt: file.getLastUpdated()
        ? file.getLastUpdated().toISOString()
        : '',
    });
    if (out.length >= 400) return;
  }
}

function listOsDrive_(p) {
  try {
    const osNumber = String(p.osNumber || p.number || '').trim();
    if (!osNumber) return json_({ ok: false, error: 'OS sem número' });
    const key = osFolderKey_(osNumber);
    const osFolder = driveFindFolder_(filesRoot_(), key);
    if (!osFolder) {
      return json_({
        ok: true,
        osNumber: osNumber,
        folderKey: key,
        folderUrl: '',
        files: [],
      });
    }
    const files = [];
    listOsDriveFilesRecursive_(osFolder, '', files, 0);
    return json_({
      ok: true,
      osNumber: osNumber,
      folderKey: key,
      folderUrl: osFolder.getUrl(),
      files: files,
    });
  } catch (error) {
    return json_({
      ok: false,
      error: String((error && error.message) || error),
    });
  }
}

function saveOsFolder_(p) {
  const osId = String(p.osId || '').trim();
  const osNumber = String(p.osNumber || '').trim();
  const conflict = String(p.conflict || 'replace').toLowerCase();
  logOsFolder_(osId, { pending: true });
  try {
    const osFolder = driveRetry_(function () {
      return driveChildFolder_(filesRoot_(), osFolderKey_(osNumber));
    });
    const cache = {};
    const files = Array.isArray(p.files) ? p.files : [];
    var saved = 0;
    var skipped = [];
    for (var i = 0; i < files.length; i++) {
      if (i > 0) Utilities.sleep(400);
      const item = files[i] || {};
      var raw = String(item.data || item.base64 || '').replace(/\s/g, '');
      const marker = 'base64,';
      const cut = raw.indexOf(marker);
      if (cut >= 0) raw = raw.slice(cut + marker.length);
      var name =
        safeDriveName_(item.name, 120) || 'arquivo_' + (i + 1);
      if (!raw) {
        skipped.push(name);
        continue;
      }
      var bytes;
      try {
        bytes = Utilities.base64Decode(raw);
      } catch (error) {
        skipped.push(name);
        continue;
      }
      const target = driveRetry_(function () {
        return osTargetFolder_(
          osFolder,
          osFolderLabel_(item.folder),
          cache,
          true,
        );
      });
      const mime = String(item.mime || mimeFromName_(name));
      const blob = Utilities.newBlob(bytes, mime, name);
      upsertDriveFile_(target, blob, conflict);
      saved++;
    }

    const folderUrl = osFolder.getUrl();
    if (skipped.length > 0) {
      const partial =
        'Não salvou no Google Drive (arquivo vazio ou corrompido): ' +
        skipped.join(', ') +
        '. Anexe de novo e salve outra vez.';
      logOsFolder_(osId, { ok: false, error: partial });
      return json_({ ok: false, error: partial, files: saved, folderUrl: folderUrl });
    }
    logOsFolder_(osId, {
      ok: true,
      sent: true,
      files: saved,
      folderUrl: folderUrl,
    });
    return json_({
      ok: true,
      sent: true,
      files: saved,
      folderUrl: folderUrl,
      message: folderUrl,
    });
  } catch (error) {
    var detail = String((error && error.message) || error);
    var who = driveScriptAccount_() || OFFICE_DRIVE_ACCOUNT_;
    if (isDriveStorageError_(detail)) {
      detail =
        'Limite excedido: Drive (armazenamento cheio). ' +
        'Esvazie a lixeira e libere espaço na conta que roda o script: ' +
        who +
        (who !== OFFICE_DRIVE_ACCOUNT_.toLowerCase()
          ? ' (deveria ser ' + OFFICE_DRIVE_ACCOUNT_ + ').'
          : '.') +
        ' Depois tente de novo.';
    } else if (isDriveLimitError_(detail)) {
      detail =
        'Limite excedido: Drive (conta do Apps Script: ' +
        who +
        '). Se não for ' +
        OFFICE_DRIVE_ACCOUNT_ +
        ', publique o script logado nessa conta. ' +
        'Se já for, espere 1–2 minutos e tente de novo.';
    }
    const message = 'Não salvou no Google Drive. ' + detail;
    logOsFolder_(osId, { ok: false, error: message });
    return json_({ ok: false, error: message });
  }
}
