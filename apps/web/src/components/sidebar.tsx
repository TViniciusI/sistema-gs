"use client";

import Link from "next/link";
import { usePathname } from "next/navigation";
import { logout } from "@/app/login/actions";
import { BrandLogo } from "@/components/brand";
import { Icons } from "@/components/icons";

const GROUPS = [
  {
    label: "Início",
    items: [
      { href: "/", label: "Área de trabalho", icon: Icons.home },
      { href: "/agenda", label: "Agenda da semana", icon: Icons.calendar },
    ],
  },
  {
    label: "Operação",
    items: [
      { href: "/os", label: "Ordens de serviço", icon: Icons.clipboard },
      { href: "/arquivos", label: "Arquivos / Drive", icon: Icons.clipboard },
      { href: "/clientes", label: "Clientes e sistemas", icon: Icons.building },
      { href: "/equipe", label: "Funcionários", icon: Icons.users },
      { href: "/documentos", label: "Documentos RH", icon: Icons.users },
    ],
  },
  {
    label: "Qualidade",
    items: [
      { href: "/calibracao", label: "Calibração", icon: Icons.wrench },
      { href: "/certificados", label: "Certificados", icon: Icons.shield },
      { href: "/padroes", label: "Padrões", icon: Icons.shield },
      { href: "/fluidos", label: "Fluidos", icon: Icons.wrench },
      { href: "/tabelas", label: "Tabelas 20 °C", icon: Icons.table },
      { href: "/vencimentos", label: "Vencimentos", icon: Icons.clock },
    ],
  },
  {
    label: "Sistema",
    items: [
      { href: "/configuracoes", label: "Configurações", icon: Icons.settings },
      { href: "/campo", label: "App de campo", icon: Icons.phone },
    ],
  },
];

export const APP_NAV_HREFS = [
  ...GROUPS.flatMap((group) => group.items.map((item) => item.href)),
];

export function Sidebar({
  name,
  role,
  collapsed,
  onToggle,
}: {
  name: string;
  role: string;
  collapsed: boolean;
  onToggle: () => void;
}) {
  const pathname = usePathname();
  const initial = name.trim().charAt(0).toUpperCase() || "G";

  return (
    <aside
      className={`sticky top-0 flex h-dvh shrink-0 flex-col bg-navy text-paper transition-[width] duration-200 ${
        collapsed ? "w-[84px]" : "w-[292px]"
      }`}
    >
      <div className="relative border-b border-white/10 px-4 py-5">
        <div className="absolute inset-x-0 bottom-0 h-[3px] bg-brass" />
        <Link
          href="/"
          className={`flex flex-col items-start gap-2 ${
            collapsed ? "mx-auto items-center" : ""
          }`}
        >
          <BrandLogo
            variant={collapsed ? "mark" : "full"}
            className={
              collapsed
                ? "h-10 w-10"
                : "h-auto w-[132px] max-h-[112px]"
            }
          />
          {!collapsed ? (
            <p className="text-[10px] font-semibold uppercase tracking-[0.28em] text-brass">
              Escritório GS
            </p>
          ) : null}
        </Link>
      </div>

      <nav className="flex-1 overflow-y-auto px-2.5 py-4">
        {GROUPS.map((group) => (
          <div key={group.label} className="mb-5">
            {!collapsed ? (
              <p className="mb-2 px-2.5 text-[10px] font-semibold uppercase tracking-[0.2em] text-brass/80">
                {group.label}
              </p>
            ) : null}
            <div className="flex flex-col gap-1">
              {group.items.map((item) => {
                const active =
                  item.href === "/"
                    ? pathname === "/"
                    : pathname.startsWith(item.href);
                return (
                  <Link
                    key={item.href}
                    href={item.href}
                    prefetch
                    title={item.label}
                    className={`flex items-center gap-3 rounded-xl px-3 py-2.5 text-[13px] font-medium ${
                      active
                        ? "bg-brass text-navy shadow-[0_8px_20px_rgba(197,158,57,0.28)]"
                        : "text-paper/75 hover:bg-white/8 hover:text-paper"
                    } ${collapsed ? "justify-center px-0" : ""}`}
                  >
                    <span className={active ? "text-navy" : "text-brass"}>
                      {item.icon}
                    </span>
                    {!collapsed ? (
                      <span className="flex-1 truncate">{item.label}</span>
                    ) : null}
                  </Link>
                );
              })}
            </div>
          </div>
        ))}
      </nav>

      <div className="border-t border-white/10 px-3 py-4">
        <div
          className={`flex items-center gap-3 ${collapsed ? "justify-center" : ""}`}
        >
          <div className="flex h-10 w-10 items-center justify-center rounded-full bg-brass text-sm font-bold text-navy">
            {initial}
          </div>
          {!collapsed ? (
            <div className="min-w-0">
              <div className="truncate text-[13px] font-semibold text-paper">
                {name}
              </div>
              <div className="truncate text-[11px] text-paper/50">{role}</div>
            </div>
          ) : null}
        </div>

        {!collapsed ? (
          <div className="mt-3 flex items-center gap-2">
            <button
              type="button"
              onClick={onToggle}
              className="flex-1 rounded-xl border border-white/15 px-3 py-2 text-[12px] text-paper/70 hover:bg-white/8"
            >
              Recolher
            </button>
            <form action={logout}>
              <button
                type="submit"
                className="rounded-xl border border-white/15 px-3 py-2 text-brass hover:bg-white/8"
                title="Sair"
              >
                {Icons.logout}
              </button>
            </form>
          </div>
        ) : (
          <button
            type="button"
            onClick={onToggle}
            className="mt-3 flex w-full items-center justify-center rounded-xl border border-white/15 py-2 text-paper/70"
            aria-label="Expandir menu"
          >
            {Icons.menu}
          </button>
        )}
      </div>
    </aside>
  );
}
