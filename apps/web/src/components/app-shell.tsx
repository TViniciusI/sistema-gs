"use client";

import { useEffect, useState, type ReactNode } from "react";
import { useRouter } from "next/navigation";
import { PageFade } from "@/components/page-fade";
import { APP_NAV_HREFS, Sidebar } from "@/components/sidebar";
import { Icons } from "@/components/icons";

export function AppShell({
  name,
  role,
  children,
}: {
  name: string;
  role: string;
  children: ReactNode;
}) {
  const router = useRouter();
  const [collapsed, setCollapsed] = useState(false);

  useEffect(() => {
    APP_NAV_HREFS.forEach((href) => {
      void router.prefetch(href);
    });
  }, [router]);

  return (
    <div className="flex min-h-full bg-paper">
      <Sidebar
        name={name}
        role={role}
        collapsed={collapsed}
        onToggle={() => setCollapsed((value) => !value)}
      />
      <div className="flex min-w-0 flex-1 flex-col">
        <div className="sticky top-0 z-10 flex items-center justify-between border-b border-line bg-paper/90 px-6 py-3 backdrop-blur-md">
          <div className="flex items-center gap-3">
            <button
              type="button"
              onClick={() => setCollapsed((value) => !value)}
              className="flex h-9 w-9 items-center justify-center rounded-md text-navy/70 hover:bg-white hover:text-navy"
              aria-label={collapsed ? "Expandir menu" : "Recolher menu"}
            >
              {Icons.menu}
            </button>
            <p className="text-[11px] font-medium uppercase tracking-[0.28em] text-brass">
              Demonstração · dados ilustrativos
            </p>
          </div>
          <p className="text-[10px] uppercase tracking-[0.22em] text-navy/40">
            Desenvolvido por Vinicius Magalhães
          </p>
        </div>
        <main className="flex-1 px-8 py-8">
          <PageFade>{children}</PageFade>
        </main>
      </div>
    </div>
  );
}
