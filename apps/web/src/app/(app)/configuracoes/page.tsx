import { ConfiguracoesBoard } from "@/components/configuracoes/configuracoes-board";
import { PageHeader } from "@/components/ui";
import { getProfile } from "@/lib/auth";
import { getCampoDriveStatus } from "@/lib/campo-data";
import { getGreetWithFullName } from "@/lib/prefs";

export const dynamic = "force-dynamic";

export default async function ConfiguracoesPage() {
  const [profile, drive, greetWithFullName] = await Promise.all([
    getProfile(),
    getCampoDriveStatus(),
    getGreetWithFullName(),
  ]);

  return (
    <div className="space-y-5">
      <PageHeader
        eyebrow="Sistema"
        title="Configurações"
        description="Conta, senha e Google Drive — as mesmas ações do GS Campo, no escritório."
      />
      <ConfiguracoesBoard
        profile={{
          name: profile?.full_name || "",
          login: profile?.login || "",
          email: profile?.email || "",
          phone: profile?.phone || "",
          roleLabel: profile?.role_label || profile?.role || "",
          permissions: profile?.permissions || "geral",
          source: profile?.source || "",
          canEditCampo: profile?.source === "campo",
        }}
        drive={{
          ok: drive.ok,
          ownerEmail: drive.ownerEmail,
          folderName: drive.folderName,
          folderUrl: drive.folderUrl,
          wrongOwner: drive.wrongOwner,
          error: drive.error,
        }}
        greetWithFullName={greetWithFullName}
      />
    </div>
  );
}
