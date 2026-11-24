import Link from "next/link";
import { EquipeHorasPanel } from "@/components/equipe/equipe-horas-panel";
import { EquipePeopleBoard } from "@/components/equipe/equipe-people-board";
import {
  EquipeTabs,
  type EquipeTab,
} from "@/components/equipe/equipe-tabs";
import { PageHeader } from "@/components/ui";
import { getProfile } from "@/lib/auth";
import { listCampoUsers } from "@/lib/campo-data";
import {
  buildEquipeHorasRows,
  currentYearMonth,
  listFieldTechnicians,
} from "@/lib/campo-data/equipe-horas";

export const dynamic = "force-dynamic";

function parseTab(raw: string | undefined): EquipeTab {
  if (raw === "inativos" || raw === "pendentes" || raw === "horas") return raw;
  return "ativos";
}

export default async function EquipePage({
  searchParams,
}: {
  searchParams: Promise<{ tab?: string; tech?: string; month?: string }>;
}) {
  const params = await searchParams;
  const tab = parseTab(params.tab);
  const [users, profile] = await Promise.all([
    listCampoUsers(),
    getProfile(),
  ]);
  const canAdmin =
    profile?.role === "admin" || profile?.role === "office";

  const ativos = users.filter(
    (u) => u.active && u.status.trim().toLowerCase() !== "recusado",
  );
  const inativos = users.filter((u) => !u.active);
  const pendentes = users.filter(
    (u) => u.status.trim().toLowerCase() === "pendente",
  );

  const month =
    params.month && /^\d{4}-\d{2}$/.test(params.month)
      ? params.month
      : currentYearMonth();

  const fieldTechs = listFieldTechnicians(users);
  const horas =
    tab === "horas"
      ? await buildEquipeHorasRows({
          users,
          techFilter: params.tech,
          month,
        })
      : null;

  const people =
    tab === "ativos"
      ? ativos
      : tab === "inativos"
        ? inativos
        : tab === "pendentes"
          ? pendentes
          : [];

  return (
    <div className="space-y-5">
      <PageHeader
        eyebrow="Cadastros"
        title="Funcionários"
        description="Acessos, ativos/inativos e banco de horas dos técnicos de campo — mesma planilha do GS Campo."
        action={
          tab !== "horas" ? (
            <Link
              href="/equipe?tab=horas"
              className="rounded-xl bg-brass px-4 py-2.5 text-sm font-semibold text-navy hover:bg-brass-2"
            >
              Ver horas de campo
            </Link>
          ) : null
        }
      />

      <EquipeTabs
        active={tab}
        counts={{
          ativos: ativos.length,
          inativos: inativos.length,
          pendentes: pendentes.length,
          tecnicos: fieldTechs.length,
        }}
      />

      {tab === "horas" && horas ? (
        <EquipeHorasPanel
          technicians={horas.technicians.map((u) => ({
            name: u.name,
            email: u.email,
            login: u.login,
          }))}
          selectedName={horas.selected?.name || null}
          month={month}
          rows={horas.rows}
        />
      ) : (
        <EquipePeopleBoard
          canAdmin={canAdmin}
          people={people.map((u) => ({
            email: u.email,
            login: u.login,
            name: u.name,
            phone: u.phone,
            role: u.role,
            status: u.status,
            active: u.active,
            permissions: u.permissions,
            cargo: u.cargo,
            funcao: u.funcao,
          }))}
          empty={
            tab === "pendentes"
              ? "Nenhum acesso pendente."
              : tab === "inativos"
                ? "Nenhum funcionário inativo."
                : "Nenhum funcionário ativo."
          }
        />
      )}
    </div>
  );
}
