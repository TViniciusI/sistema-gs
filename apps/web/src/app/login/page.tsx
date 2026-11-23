import { BrandLogo } from "@/components/brand";
import { LoginForm } from "./login-form";

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

        <div className="relative z-10 flex flex-1 flex-col justify-center px-14 py-14">
          <BrandLogo variant="mark" className="h-[76px] w-auto" />
          <p className="mt-5 text-[11px] font-medium uppercase tracking-[0.36em] text-brass">
            GS Soluções Técnicas
          </p>
          <h1 className="mt-5 max-w-[14ch] font-serif text-[2.75rem] leading-[1.15] tracking-tight">
            Escritório GS
          </h1>
          <p className="mt-5 max-w-[36ch] text-[15px] leading-7 text-paper/70">
            Gestão técnica no navegador, com os mesmos usuários do GS Campo.
          </p>
        </div>
      </aside>

      <div className="relative flex flex-col bg-paper">
        <div className="border-b border-navy bg-navy px-6 py-5 text-paper lg:hidden">
          <p className="text-[10px] font-medium uppercase tracking-[0.32em] text-brass">
            GS Soluções Técnicas
          </p>
          <p className="mt-2 font-serif text-xl leading-snug">Escritório GS</p>
        </div>

        <div className="flex flex-1 flex-col items-center justify-center px-6 py-14">
          <main className="page-enter w-full max-w-[420px]">
            <div className="rounded-3xl border border-navy/10 bg-white px-8 py-9 shadow-[0_28px_64px_rgba(12,31,51,0.1)]">
              <div className="mx-auto h-[3px] w-11 rounded-full bg-brass" />
              <BrandLogo
                priority
                variant="mark"
                className="mx-auto mt-6 h-[68px] w-auto"
              />

              <h2 className="mt-5 text-center font-serif text-2xl text-navy">
                Entrar
              </h2>
              <p className="mx-auto mt-2 max-w-[34ch] text-center text-sm leading-6 text-muted">
                Use o login e a senha do aplicativo GS Campo.
              </p>

              <LoginForm />
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
