import Link from "next/link";
import { UserDecideActions } from "@/components/equipe/user-decide-actions";
import { DataTable, PageHeader, StatusPill } from "@/components/ui";
import { getProfile } from "@/lib/auth";
import { listCampoUsers } from "@/lib/campo-data";
import { campoRoleLabel } from "@/lib/campo-data/labels";

export const dynamic = "force-dynamic";

export default async function EquipePage() {
  const [users, profile] = await Promise.all([
    listCampoUsers(),
    getProfile(),
  ]);
  const canDecide =
    profile?.role === "admin" || profile?.role === "office";
  const pending = users.filter(
    (u) => u.status.trim().toLowerCase() === "pendente",
  ).length;

  return (
    <div>
      <PageHeader
        eyebrow="Cadastros"
        title="Funcionários e acessos"
        description={
          pending > 0
            ? `${pending} pendente(s) de aprovação — mesmos usuários do GS Campo.`
            : "Mesmos usuários do GS Campo — aprovação, papel e módulos."
        }
        action={
          <Link
            href="/equipe/horas"
            className="rounded-xl bg-brass px-4 py-2.5 text-sm font-semibold text-navy hover:bg-brass-2"
          >
            Horas de campo
          </Link>
        }
      />
      <DataTable
        headers={
          canDecide
            ? ["Nome", "Login", "Papel", "Status", "Ativo", "Ação"]
            : ["Nome", "Login", "Papel", "Status", "Ativo"]
        }
        empty="Não foi possível carregar os usuários (token/planilha)."
        rows={users.map((user) => {
          const base = [
            <div key={user.login}>
              <div className="font-medium text-navy">{user.name}</div>
              <div className="text-xs text-muted">{user.email}</div>
            </div>,
            user.login || "—",
            campoRoleLabel(user.role),
            <StatusPill
              key={`${user.login}-st`}
              label={user.status}
              tone={
                user.status === "aprovado"
                  ? "ok"
                  : user.status === "pendente"
                    ? "warn"
                    : "danger"
              }
            />,
            user.active ? "Sim" : "Não",
          ];
          if (!canDecide) return base;
          return [
            ...base,
            <UserDecideActions
              key={`${user.login}-act`}
              email={user.email}
              login={user.login}
              status={user.status}
            />,
          ];
        })}
      />
    </div>
  );
}
