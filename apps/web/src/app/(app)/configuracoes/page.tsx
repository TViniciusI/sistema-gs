import { getProfile } from "@/lib/auth";
import { getCampoDriveStatus } from "@/lib/campo-data";
import { PageHeader, Panel } from "@/components/ui";

export const dynamic = "force-dynamic";

export default async function ConfiguracoesPage() {
  const [profile, drive] = await Promise.all([
    getProfile(),
    getCampoDriveStatus(),
  ]);

  return (
    <div>
      <PageHeader
        eyebrow="Sistema"
        title="Configurações"
        description="Conta do escritório e status do Google Drive compartilhado com o GS Campo."
      />
      <div className="grid gap-4 lg:grid-cols-2">
        <Panel>
          <h2 className="mb-3 font-serif text-lg text-navy">Sessão</h2>
          <dl className="space-y-3 text-sm">
            <div>
              <dt className="text-xs uppercase tracking-wide text-muted">
                Nome
              </dt>
              <dd>{profile?.full_name || "—"}</dd>
            </div>
            <div>
              <dt className="text-xs uppercase tracking-wide text-muted">
                Login
              </dt>
              <dd>{profile?.login || profile?.email || "—"}</dd>
            </div>
            <div>
              <dt className="text-xs uppercase tracking-wide text-muted">
                Origem
              </dt>
              <dd>
                {profile?.source === "campo"
                  ? "Cadastro GS Campo (planilha)"
                  : profile?.source || "—"}
              </dd>
            </div>
            <div>
              <dt className="text-xs uppercase tracking-wide text-muted">
                Permissões
              </dt>
              <dd>{profile?.permissions || "geral"}</dd>
            </div>
          </dl>
        </Panel>

        <Panel>
          <h2 className="mb-3 font-serif text-lg text-navy">Google Drive</h2>
          <dl className="space-y-3 text-sm">
            <div>
              <dt className="text-xs uppercase tracking-wide text-muted">
                Status
              </dt>
              <dd>
                {drive.ok
                  ? "Conectado"
                  : drive.error || "Indisponível"}
              </dd>
            </div>
            {drive.ownerEmail ? (
              <div>
                <dt className="text-xs uppercase tracking-wide text-muted">
                  Conta
                </dt>
                <dd>{drive.ownerEmail}</dd>
              </div>
            ) : null}
            {drive.folderName ? (
              <div>
                <dt className="text-xs uppercase tracking-wide text-muted">
                  Pasta das OS
                </dt>
                <dd>
                  {drive.folderUrl ? (
                    <a
                      href={drive.folderUrl}
                      target="_blank"
                      rel="noreferrer"
                      className="text-navy hover:underline"
                    >
                      {drive.folderName}
                    </a>
                  ) : (
                    drive.folderName
                  )}
                </dd>
              </div>
            ) : null}
            {drive.wrongOwner ? (
              <p className="text-sm text-red-700">
                Aviso: pasta com dono diferente do administrativo@.
              </p>
            ) : null}
          </dl>
        </Panel>
      </div>
    </div>
  );
}
