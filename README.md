# GS Soluções — Sistema de gestão

Demonstração navegável para apresentar ao cliente. **Não é o sistema em produção**: os dados são ilustrativos, ficam na sessão e não gravam em banco.

## Como mostrar

```bash
npm install
npm run dev
```

Abra [http://localhost:3000](http://localhost:3000) e entre com o **mesmo usuário/senha do GS Campo** (cadastro da planilha).

O escritório autentica e lê a **mesma planilha/Drive do app** (`LOGIN_GATE_URL` em `apps/web/.env.example`):

- Login compartilhado
- Clientes e sistemas/instrumentos (com exclusão na fonte da verdade)
- OS e RDOs
- Equipe / acessos
- Status do Google Drive e atalho de arquivos

Algumas telas legadas (locais/equipamentos demo) ainda misturam dados ilustrativos — o núcleo operacional já vem do Campo.

### Roteiro sugerido

1. **Painel** — OS em aberto, vencimentos e últimas ordens
2. **OS GS 036/26** — RDO, ponto, GPS, fotos e assinatura da ALESAT/MG
3. **Certificado 2303126** — prévia do documento de calibração
4. **Vencimentos** — padrão MM-001 a vencer
5. **App do técnico** (`/campo`) — celular com agenda, foto e assinatura offline

Cadastros (cliente, local, equipe, nova OS) funcionam **só nesta sessão** do navegador. Ao reiniciar o `npm run dev`, os dados de exemplo voltam.

## App Flutter (campo)

O caminho certo para o técnico usar no computador é **o navegador** (e, se quiser ícone no desktop, instalar pelo Chrome/Edge). Não precisa de `.exe`.

```bash
cd apps/mobile
flutter pub get
flutter run -d chrome
```

Para publicar na Netlify, veja `apps/mobile/README.md`. Sem chave, sem `--dart-define` na demo. Entrar → agenda → OS 036/26.

## O que ainda não entra

Banco real (Supabase), login de produção, PDF do RDO, motor de incerteza GUM, horas extras e sincronização offline de verdade. O esqueleto do schema está em `supabase/migrations/` para o passo seguinte.

## Pastas

```
apps/web          admin Next.js (demonstração)
apps/mobile       Flutter (demonstração de campo)
packages/shared   status da OS, papéis, formatação
supabase/         migrations para quando o banco existir
```

Planilhas de referência do cliente (`RDO TESTE.xlsm`, `CERTIFICADO TESTE.xlsx`) estão na raiz do repositório.
