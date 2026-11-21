"use client";

import { useEffect, useState, type ReactNode } from "react";
import { useRouter } from "next/navigation";
import { PageFade } from "@/components/page-fade";
import { APP_NAV_HREFS, Sidebar } from "@/components/sidebar";
import { Icons } from "@/components/icons";

export function AppShell({
  name,
  role,
  source,
  children,
}: {
  name: string;
  role: string;
  source?: "campo" | "demo" | "supabase";
  children: ReactNode;
}) {
  const router = useRouter();
  const [collapsed, setCollapsed] = useState(false);

  useEffect(() => {
    APP_NAV_HREFS.forEach((href) => {
      void router.prefetch(href);
    });
  }, [router]);

  const banner =
    source === "campo"
      ? "Mesma base do GS Campo"
      : source === "supabase"
        ? "Conta conectada"
        : "Demonstração";

  return (
    <div className="flex min-h-full bg-paper">
      <Sidebar
        name={name}
        role={role}
        collapsed={collapsed}
        onToggle={() => setCollapsed((value) => !value)}
      />
      <div className="flex min-w-0 flex-1 flex-col">
        <div className="sticky top-0 z-10 flex items-center justify-between border-b border-navy/10 bg-paper/90 px-6 py-3.5 backdrop-blur-md">
          <div className="flex items-center gap-3">
            <button
              type="button"
              onClick={() => setCollapsed((value) => !value)}
              className="flex h-10 w-10 items-center justify-center rounded-xl border border-navy/10 bg-white text-navy/70 hover:text-navy"
              aria-label={collapsed ? "Expandir menu" : "Recolher menu"}
            >
              {Icons.menu}
            </button>
            <div>
              <p className="text-[11px] font-semibold uppercase tracking-[0.28em] text-brass">
                {banner}
              </p>
              <p className="text-[12px] text-navy/45">
                Escritório responsivo · extensão do app de campo
              </p>
            </div>
          </div>
          <p className="hidden text-[10px] uppercase tracking-[0.22em] text-navy/35 sm:block">
            Desenvolvido por Vinicius Magalhães
          </p>
        </div>
        <main className="flex-1 px-5 py-7 md:px-8 md:py-8">
          <PageFade>{children}</PageFade>
        </main>
      </div>
    </div>
  );
}
