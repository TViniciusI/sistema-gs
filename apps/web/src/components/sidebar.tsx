"use client";

import Link from "next/link";
import { usePathname } from "next/navigation";
import { logout } from "@/app/login/actions";
import { BrandLogo } from "@/components/brand";
import { Icons } from "@/components/icons";

const GROUPS = [
  {
    label: "Operação",
    icon: Icons.home,
    items: [
      { href: "/", label: "Painel", icon: Icons.home },
      { href: "/os", label: "Ordens de serviço", icon: Icons.clipboard, chevron: true },
      { href: "/agenda", label: "Agenda", icon: Icons.calendar },
    ],
  },
  {
    label: "Cadastros",
    icon: Icons.building,
    items: [
      { href: "/clientes", label: "Clientes", icon: Icons.building, chevron: true },
      { href: "/locais", label: "Locais", icon: Icons.pin, chevron: true },
      { href: "/equipamentos", label: "Equipamentos", icon: Icons.wrench, chevron: true },
      { href: "/equipe", label: "Equipe", icon: Icons.users, chevron: true },
    ],
  },
  {
    label: "Qualidade",
    icon: Icons.shield,
    items: [
      { href: "/certificados", label: "Certificados", icon: Icons.shield, chevron: true },
      { href: "/tabelas", label: "Tabelas 20 °C", icon: Icons.table, chevron: true },
      { href: "/vencimentos", label: "Vencimentos", icon: Icons.clock, chevron: true },
    ],
  },
  {
    label: "Campo",
    icon: Icons.phone,
    items: [{ href: "/campo", label: "App do técnico", icon: Icons.phone }],
  },
];

export const APP_NAV_HREFS = [
  ...GROUPS.flatMap((group) => group.items.map((item) => item.href)),
  "/configuracoes",
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
      className={`sticky top-0 flex h-dvh shrink-0 flex-col border-r border-line bg-white shadow-[4px_0_24px_rgba(12,31,51,0.04)] transition-[width] duration-200 ${
        collapsed ? "w-[76px]" : "w-[272px]"
      }`}
    >
      <div className="relative border-b border-line bg-white px-4 py-4">
        <Link
          href="/"
          className={`block ${collapsed ? "mx-auto w-[44px] overflow-hidden" : "mx-auto w-[158px]"}`}
        >
          <BrandLogo className="h-auto w-full" />
        </Link>
        {!collapsed ? (
          <button
            type="button"
            onClick={onToggle}
            className="absolute top-3 right-3 flex h-8 w-8 items-center justify-center rounded-full border border-line text-brass hover:bg-paper"
            aria-label="Recolher menu"
          >
            {Icons.chevronLeft}
          </button>
        ) : null}
      </div>

      {collapsed ? (
        <button
          type="button"
          onClick={onToggle}
          className="mx-auto mt-3 flex h-8 w-8 items-center justify-center rounded-full border border-line text-navy/60 hover:text-navy"
          aria-label="Expandir menu"
        >
          {Icons.chevronRight}
        </button>
      ) : null}

      <nav className="flex-1 overflow-y-auto px-2.5 py-4">
        {GROUPS.map((group) => (
          <div key={group.label} className="mb-4">
            {!collapsed ? (
              <p className="mb-1 flex items-center gap-1.5 px-2.5 text-[10px] font-semibold uppercase tracking-[0.18em] text-brass">
                <span className="scale-90">{group.icon}</span>
                {group.label}
              </p>
            ) : null}
            <div className="flex flex-col gap-0.5">
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
                    className={`flex items-center gap-2.5 rounded-md px-2.5 py-2 text-[13px] ${
                      active
                        ? "bg-[#f3e6c8] font-semibold text-navy shadow-[inset_3px_0_0_#c59e39]"
                        : "text-navy/70 hover:bg-paper hover:text-navy"
                    } ${collapsed ? "justify-center px-0" : ""}`}
                  >
                    <span className={active ? "text-brass" : ""}>{item.icon}</span>
                    {!collapsed ? <span className="flex-1 truncate">{item.label}</span> : null}
                    {!collapsed && item.chevron ? (
                      <span className="text-navy/30">{Icons.chevronRight}</span>
                    ) : null}
                  </Link>
                );
              })}
            </div>
          </div>
        ))}
      </nav>

      {!collapsed ? (
        <div className="px-3 pb-3">
          <a
            href="mailto:cleber@gssolucoestec.com.br"
            className="flex items-center gap-3 rounded-xl border border-brass/25 bg-[#f7efdc] px-3 py-3"
          >
            <span className="text-brass">{Icons.headset}</span>
            <span className="min-w-0">
              <span className="block text-[13px] font-semibold text-brass">
                Precisa de ajuda?
              </span>
              <span className="mt-0.5 flex items-center gap-1 text-[12px] text-navy/70">
                Abrir suporte
                <span className="text-navy/30">{Icons.chevronRight}</span>
              </span>
            </span>
          </a>
        </div>
      ) : null}

      <div className="border-t border-line px-3 py-3">
        <div className={`flex items-center gap-2.5 ${collapsed ? "justify-center" : ""}`}>
          <div className="relative shrink-0">
            <div className="flex h-9 w-9 items-center justify-center rounded-full bg-brass text-sm font-semibold text-black">
              {initial}
            </div>
            <span className="absolute right-0 bottom-0 h-2.5 w-2.5 rounded-full border-2 border-white bg-ok" />
          </div>
          {!collapsed ? (
            <div className="min-w-0">
              <div className="truncate text-[13px] font-semibold text-navy">{name}</div>
              <div className="text-[11px] text-navy/45">{role}</div>
            </div>
          ) : null}
        </div>

        {!collapsed ? (
          <div className="mt-3 flex items-center gap-3 border-t border-line pt-3 text-[12px] text-navy/65">
            <Link
              href="/configuracoes"
              prefetch
              className="inline-flex items-center gap-1.5 hover:text-navy"
            >
              {Icons.settings}
              Configurações
            </Link>
            <span className="h-3 w-px bg-line" />
            <form action={logout}>
              <button
                type="submit"
                className="inline-flex items-center gap-1.5 hover:text-navy"
              >
                {Icons.logout}
                Sair
              </button>
            </form>
          </div>
        ) : (
          <form action={logout} className="mt-3 flex justify-center">
            <button type="submit" className="text-navy/50 hover:text-navy" title="Sair">
              {Icons.logout}
            </button>
          </form>
        )}
      </div>
    </aside>
  );
}
