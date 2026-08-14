import { BrandLogo } from "@/components/brand";
import { Icons } from "@/components/icons";
import { login } from "./actions";

const HIGHLIGHTS = [
  {
    icon: Icons.clipboard,
    title: "Ordens de serviço e RDO",
    text: "Agenda, equipe e registro do dia no mesmo fluxo.",
  },
  {
    icon: Icons.shield,
    title: "Certificados de calibração",
    text: "Feitos no Excel e anexados no app — o arquivo cai no escritório.",
  },
  {
    icon: Icons.phone,
    title: "App de campo",
    text: "Registros do dia, fotos, GPS e assinatura mesmo sem sinal na planta.",
  },
];

export default function LoginPage() {
  return (
    <div className="grid min-h-dvh lg:grid-cols-[minmax(0,1.05fr)_minmax(0,1fr)]">
      <aside className="relative hidden overflow-hidden bg-navy text-paper lg:flex lg:flex-col">
        <div className="absolute inset-x-0 top-0 h-[3px] bg-brass" />
        <div
          aria-hidden
          className="pointer-events-none absolute -right-28 top-1/2 size-[560px] -translate-y-1/2 rounded-full border border-brass/20"
        />
        <div
          aria-hidden
          className="pointer-events-none absolute -right-6 top-1/2 size-[380px] -translate-y-1/2 rounded-full border border-brass/25"
        />
        <div
          aria-hidden
          className="pointer-events-none absolute right-20 top-1/2 size-[210px] -translate-y-1/2 rounded-full border border-brass/35"
        />
        <div
          aria-hidden
          className="pointer-events-none absolute right-[148px] top-[calc(50%-6px)] size-3 rounded-full bg-brass"
        />
        <div
          aria-hidden
          className="pointer-events-none absolute inset-0 bg-[radial-gradient(900px_420px_at_0%_100%,rgba(197,158,57,0.14),transparent_55%)]"
        />

        <div className="relative z-10 flex flex-1 flex-col px-14 py-14">
          <p className="text-[11px] font-medium uppercase tracking-[0.36em] text-brass">
            GS Soluções Técnicas
          </p>
          <h1 className="mt-10 max-w-[14ch] font-serif text-[2.75rem] leading-[1.15] tracking-tight">
            O escritório e o campo no mesmo sistema.
          </h1>
          <p className="mt-6 max-w-[38ch] text-[15px] leading-7 text-paper/70">
            Gestão técnica para instrumentação e metrologia — da OS aos
            registros de campo, com o certificado em Excel anexado no app.
          </p>

          <ul className="mt-12 max-w-md space-y-5">
            {HIGHLIGHTS.map((item) => (
              <li key={item.title} className="flex gap-4">
                <span className="mt-0.5 flex h-9 w-9 items-center justify-center border border-brass/35 text-brass">
                  {item.icon}
                </span>
                <span>
                  <span className="block text-sm font-medium text-paper">
                    {item.title}
                  </span>
                  <span className="mt-0.5 block text-[13px] leading-5 text-paper/55">
                    {item.text}
                  </span>
                </span>
              </li>
            ))}
          </ul>

          <p className="mt-auto pt-16 text-[10px] uppercase tracking-[0.24em] text-paper/35">
            Demonstração para apresentação ao cliente
          </p>
        </div>
      </aside>

      <div className="relative flex flex-col bg-paper">
        <div className="border-b border-navy bg-navy px-6 py-5 text-paper lg:hidden">
          <p className="text-[10px] font-medium uppercase tracking-[0.32em] text-brass">
            GS Soluções Técnicas
          </p>
          <p className="mt-2 font-serif text-xl leading-snug">
            Sistema de gestão técnica
          </p>
        </div>

        <div className="flex flex-1 flex-col items-center justify-center px-6 py-14">
          <main className="page-enter w-full max-w-[420px]">
            <div className="border border-line bg-white px-8 py-9 shadow-[0_28px_64px_rgba(12,31,51,0.08)]">
              <div className="mx-auto h-[3px] w-11 bg-brass" />
              <BrandLogo priority className="mx-auto mt-6 h-auto w-[168px]" />

              <p className="mt-3 text-center text-[11px] font-medium uppercase tracking-[0.32em] text-brass">
                Acesso ao sistema
              </p>
              <h2 className="mt-3 text-center font-serif text-2xl text-navy">
                Entrar na gestão GS
              </h2>
              <p className="mx-auto mt-2 max-w-[34ch] text-center text-sm leading-6 text-muted">
                Sessão de demonstração com dados ilustrativos da OS 036/26 e do
                certificado de calibração.
              </p>

              <form action={login} className="mt-8 space-y-4">
                <label className="block text-left">
                  <span className="mb-1.5 block text-[11px] font-medium uppercase tracking-[0.16em] text-muted">
                    Usuário
                  </span>
                  <input
                    name="email"
                    type="email"
                    autoComplete="username"
                    defaultValue="cleber@gssolucoestec.com.br"
                    className="w-full rounded-[2px] border border-line bg-paper/40 px-3 py-2.5 text-sm text-ink outline-none focus:border-brass"
                  />
                </label>
                <label className="block text-left">
                  <span className="mb-1.5 block text-[11px] font-medium uppercase tracking-[0.16em] text-muted">
                    Senha
                  </span>
                  <input
                    name="password"
                    type="password"
                    autoComplete="current-password"
                    defaultValue="demonstracao"
                    className="w-full rounded-[2px] border border-line bg-paper/40 px-3 py-2.5 text-sm text-ink outline-none focus:border-brass"
                  />
                </label>
                <button
                  type="submit"
                  className="mt-2 w-full rounded-[2px] bg-brass px-6 py-3.5 text-sm font-semibold tracking-[0.08em] text-black hover:bg-brass-2 hover:shadow-[0_8px_24px_rgba(197,158,57,0.28)]"
                >
                  Entrar na demonstração
                </button>
              </form>

              <div className="mt-6 flex items-center gap-3 border-t border-line pt-5">
                <span className="flex h-9 w-9 items-center justify-center bg-navy font-serif text-sm text-brass">
                  C
                </span>
                <p className="text-left text-sm leading-5">
                  <span className="block font-medium text-navy">
                    Cleber Guimarães
                  </span>
                  <span className="text-xs text-muted">Administrador · sessão demo</span>
                </p>
              </div>
            </div>
          </main>

          <p className="mt-10 text-[10px] uppercase tracking-[0.22em] text-navy/40">
            Desenvolvido por Vinicius Magalhães
          </p>
        </div>
      </div>
    </div>
  );
}
