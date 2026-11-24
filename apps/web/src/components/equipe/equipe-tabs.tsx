import Link from "next/link";

export type EquipeTab = "ativos" | "inativos" | "pendentes" | "horas";

export function EquipeTabs({
  active,
  counts,
}: {
  active: EquipeTab;
  counts: {
    ativos: number;
    inativos: number;
    pendentes: number;
    tecnicos: number;
  };
}) {
  const items: Array<{ key: EquipeTab; label: string; hint: string }> = [
    { key: "ativos", label: "Ativos", hint: String(counts.ativos) },
    { key: "inativos", label: "Inativos", hint: String(counts.inativos) },
    { key: "pendentes", label: "Pendentes", hint: String(counts.pendentes) },
    {
      key: "horas",
      label: "Horas de campo",
      hint: `${counts.tecnicos} téc.`,
    },
  ];

  return (
    <div className="flex flex-wrap gap-2 rounded-2xl border border-navy/10 bg-white p-1.5">
      {items.map((item) => {
        const on = active === item.key;
        const href =
          item.key === "ativos"
            ? "/equipe"
            : `/equipe?tab=${item.key}`;
        return (
          <Link
            key={item.key}
            href={href}
            className={[
              "rounded-xl px-3.5 py-2 text-sm font-medium transition",
              on
                ? "bg-navy text-brass"
                : "text-navy/65 hover:bg-paper hover:text-navy",
            ].join(" ")}
          >
            {item.label}
            <span className={on ? "text-paper/55" : "text-navy/35"}>
              {" "}
              · {item.hint}
            </span>
          </Link>
        );
      })}
    </div>
  );
}
