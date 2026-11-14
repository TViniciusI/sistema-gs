# Dono único: administrativo@gssolucoestec.com.br

O app grava RDO/fotos/anexos/certificados na pasta do Google Drive pela
conta que **implanta** o Apps Script (`login_gate.gs`).

Se o script continuar no Gmail pessoal, o erro `Limite excedido: Drive`
aparece mesmo com o `administrativo@` tendo 2 TB livres.

## 1. Transferir a pasta e os arquivos (automatizado)

Faça isto no projeto Apps Script que **ainda é o dono atual** dos arquivos
(ex.: aberto com o Gmail pessoal que criou a pasta).

1. Cole o `login_gate.gs` atualizado (se ainda não colou).
2. Se o editor pedir autorização de novo, aceite (escopo Drive).
3. No seletor de funções, escolha **`transferOsDriveToAdministrativo`** → ▶️.
4. Leia o resultado no log / painel inferior:
   - Se disser **Parcial**, rode **`continueTransferOsDriveToAdministrativo`**
     de novo (pode repetir) até dizer **concluída**.
5. Entre no Chrome como **`administrativo@gssolucoestec.com.br`** e:
   - no projeto Apps Script (compartilhado ou cópia nesta conta), rode  
     **`acceptPendingOsDriveOwnership`** → ▶️  
     (se disser Parcial: **`continueAcceptPendingOsDriveOwnership`**);  
   - ou aceite os e-mails/convites de propriedade no Drive.

Conferir: `statusTransferOsDriveToAdministrativo` (fila em andamento)  
e a pasta  
`https://drive.google.com/drive/folders/1VZHSOnhNrTgccGU-aRrTD4v3hriE2jnC`  
→ Compartilhar → o proprietário deve ser `administrativo@`.

A transferência só move o que a conta atual **ainda é dona**. Arquivos de
terceiros são ignorados. Arquivos **novos** só nascem no administrativo@
depois do passo 2 (script implantado como administrativo@).

## 2. Apps Script na conta certa

Em Chrome, saia das outras contas Google ou use janela anônima.  
Entre só com `administrativo@gssolucoestec.com.br`.  
Abra [script.google.com](https://script.google.com).

## 3. Criar (ou copiar) o projeto nesta conta

- Novo projeto → cole o conteúdo de `login_gate.gs`.  
- Ou: no projeto antigo (Gmail), Arquivo → Fazer uma cópia →  
  compartilhe/transfira a cópia para administrativo@ e abra a cópia  
  já como administrativo@.

## 4. Autorizar e publicar

- Rode `bindGsCampoSheet` (▶️).  
- Rode `authorizeDriveFiles` → Aceitar.  
- Rode `authorizeMail`, `authorizeStaffDocs`, `authorizeClientPayloads`.  
- Implantar → Nova implantação (ou lápis se for a mesma):  
  - Tipo: app da Web  
  - Executar como: **eu** (= administrativo@)  
  - Quem tem acesso: **Qualquer pessoa**  
- Copie a URL `/exec`.

## 5. App

Se a URL `/exec` mudou, atualize `loginGateUrl` em  
`apps/mobile/lib/core/config.dart` e publique o site de novo.  
Em Configurações → Google Drive deve mostrar  
`administrativo@gssolucoestec.com.br` **sem aviso vermelho**.

## Como conferir

Em Configurações (Cleber/dev), se ainda aparecer aviso de dono errado ou
o envio falar em “Gmail pessoal”, o passo 2–4 não ficou na conta
administrativo@.
