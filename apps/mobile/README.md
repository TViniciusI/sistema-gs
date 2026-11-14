# GS Campo

Aplicativo de campo: o escritório gera a OS (CNPJ, cliente, dados do RDO e técnico) e o técnico cumpre a agenda das OS pendentes.

## Navegador ou executável?

**Use o navegador (Netlify).** É o melhor caminho para este app:

- Abre no celular, tablet e computador com o mesmo link
- Atualiza sozinho quando publicamos
- No Chrome ou Edge do Windows dá para **instalar como app** (ícone na barra de endereço → Instalar GS Campo), sem gerar `.exe`
- Câmera, planilha e download do RDO funcionam em HTTPS

O `.exe` só vale se alguém precisar de janela nativa sem Chrome. Custa mais: build por máquina, SmartScreen, e cada atualização vira arquivo novo.

## Rodar local

```bash
cd apps/mobile
flutter pub get
flutter run -d chrome
```

Acesso:

- `gssolucoes` / `1234` — acesso principal da GS Soluções (escritório)
- `cleber` / `1234` — Cleber, técnico e administrativo
- `felipe`, `andre` — técnicos
- `vinicius` — desenvolvedor

Depois do login o app começa **vazio**. Cadastro e OS ficam salvos neste aparelho. Em **Configurações** cada um troca o próprio usuário e a senha.

**Criar conta** (login, senha, telefone, e-mail e setor) grava na planilha como pendente. **GS Soluções**, **Cleber** e **Vinicius** liberam o acesso em **Funcionários**.

- **Administrativo** — clientes e gerar OS
- **Técnico** — agenda e RDO do dia

### Planilha (Apps Script)

Planilha oficial:
`https://docs.google.com/spreadsheets/d/1vUj-oGqqeSZ-wmoMH1vX9on7AYHaPSG8bz3ml2i645o/edit`

Cole o script atualizado `apps/mobile/google/login_gate.gs` no Apps Script do Google e publique **Nova versão**:

1. Abrir o projeto do script (o mesmo da URL já usada no app)
2. Colar o conteúdo de `login_gate.gs` no lugar do código antigo
3. Rodar a função **`bindGsCampoSheet`** (▶️) uma vez — amarra o `SHEET_ID` à planilha oficial
4. Implantar → Gerenciar implantações → **lápis** → **Nova versão** (mesma URL — não criar outra)
5. Executar como: eu · Quem tem acesso: **Qualquer pessoa**

Se o app mostrar **"Não foi possível falar com a planilha"**, a implantação antigo pode estar 404: republicar no **mesmo lápis** (passo 4). Os dados na planilha/Google Drive não somem por causa disso.

### Google Drive (pasta da OS)

**Dono único obrigatório:** `administrativo@gssolucoestec.com.br`

Pasta, Apps Script e cota do Drive precisam ser dessa conta. Se o script for implantado com Gmail pessoal, anexos e certificados consomem o espaço errado e o limite do Drive volta a falhar.

O botão **Salvar na pasta da OS** grava RDO, fotos, anexos e certificados na pasta `DEFAULT_FILES_FOLDER_ID_` do `login_gate.gs`:

`044-26 / RDO | Fotos | Anexos | Certificados de Calibração / <tipo>`

Documentos do RH vão para `RH - <nome>` na mesma pasta.

**Setup único:**

1. **Transferir pasta/arquivos (automatizado)** — no Apps Script da conta que ainda é dona (ex. Gmail), cole o `login_gate.gs` e rode **`transferOsDriveToAdministrativo`**. Se parar no meio, **`continueTransferOsDriveToAdministrativo`**. Depois, como `administrativo@`, rode **`acceptPendingOsDriveOwnership`** (ou aceite os convites no Drive). Detalhes: `google/DONO_ADMINISTRATIVO.md`.
2. Abra [script.google.com](https://script.google.com) **já como administrativo@**. Crie/abra o projeto do GS Campo nessa conta (não no Gmail pessoal).
3. Cole o `login_gate.gs`, rode **`bindGsCampoSheet`**, depois **`authorizeDriveFiles`** → Aceitar permissões.
4. Implantar → Gerenciar implantações → lápis → **Nova versão** (Executar como: eu = administrativo@ · Quem tem acesso: Qualquer pessoa).
5. Se a URL do `/exec` mudar, atualize `loginGateUrl` em `lib/core/config.dart` e publique o app de novo. Se conseguir manter a mesma implantação/URL, melhor.

Para usar outra pasta sem mudar o código, crie a propriedade do script `GS_FILES_FOLDER_ID` com o ID da pasta (o trecho depois de `/folders/` no link).

## Publicar na Netlify (web)

### Mais rápido: arrastar a pasta

```bash
cd apps/mobile
flutter pub get
flutter build web --release
```

No painel da Netlify: **Add new site → Deploy manually** e arraste a pasta `apps/mobile/build/web` (ou o zip `apps/mobile/gs-campo-netlify.zip`).

No celular, abra o link no Chrome (Android) ou Safari (iPhone). O botão **Instalar no celular** aparece na tela de login. No iPhone: Compartilhar → Adicionar à Tela de Início.

### Automático (Git)

Crie **outro site** no mesmo repositório (o escritório Next.js continua no site atual):

1. Base directory: `apps/mobile`
2. O `netlify.toml` desta pasta já define o build
3. Opcional: variável `OFFICE_URL` com a URL pública do escritório

A URL fica algo como `https://gs-campo.netlify.app`. Cole essa URL em `NEXT_PUBLIC_CAMPO_URL` no site do escritório para o botão em `/campo`.

## APK (celular)

```bash
cd apps/mobile
flutter build apk --release
```

O arquivo sai em `build/app/outputs/flutter-apk/app-release.apk`.

## Windows (.exe), se precisar

```bash
cd apps/mobile
flutter build windows --release
```

O executável fica em `build/windows/x64/runner/Release/gs_mobile.exe`. Ainda usa a chave de debug do Android no APK; o Windows não precisa dessa chave.
