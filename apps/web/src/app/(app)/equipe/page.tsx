import { DataTable, PageHeader, StatusPill } from "@/components/ui";
import { listCampoUsers } from "@/lib/campo-data";
import { campoRoleLabel } from "@/lib/campo-data/labels";

export const dynamic = "force-dynamic";

export default async function EquipePage() {
  const users = await listCampoUsers();

  return (
    <div>
      <PageHeader
        eyebrow="Cadastros"
        title="Funcionários e acessos"
        description="Mesmos usuários do GS Campo — aprovação, papel e módulos."
      />
      <DataTable
        headers={["Nome", "Login", "Papel", "Status", "Ativo"]}
        empty="Não foi possível carregar os usuários (token/planilha)."
        rows={users.map((user) => [
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
        ])}
      />
    </div>
  );
}
