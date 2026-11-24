import Link from "next/link";
import { notFound } from "next/navigation";
import { DocumentosBoard } from "@/components/documentos/documentos-board";
import { StaffDocUploadForm } from "@/components/equipe/staff-doc-upload-form";
import { UserAdminControls } from "@/components/equipe/user-admin-controls";
import { PageHeader, StatusPill } from "@/components/ui";
import { getProfile } from "@/lib/auth";
import {
  listCampoStaffDocs,
  listCampoUsers,
} from "@/lib/campo-data";
import {
  decodeEquipePersonKey,
  matchesEquipePerson,
} from "@/lib/campo-data/equipe-keys";
import { campoRoleLabel } from "@/lib/campo-data/labels";

export const dynamic = "force-dynamic";

export default async function EquipeFichaPage({
  params,
}: {
  params: Promise<{ key: string }>;
}) {
  const { key: rawKey } = await params;
  const key = decodeEquipePersonKey(rawKey);
  const [profile, users] = await Promise.all([
    getProfile(),
    listCampoUsers(),
  ]);
  const user = users.find((u) => matchesEquipePerson(u, key));
  if (!user) notFound();

  const isOffice =
    profile?.role === "admin" || profile?.role === "office";
  const mine =
    (profile?.email || "").toLowerCase() ===
      (user.email || "").toLowerCase() ||
    (profile?.login || "").toLowerCase() ===
      (user.login || "").toLowerCase();

  if (!isOffice && !mine) {
    notFound();
  }

  const staffEmail = (user.email || "").toLowerCase();
  const docs = staffEmail
    ? await listCampoStaffDocs(staffEmail)
    : [];
  const pending = docs.filter(
    (d) => d.requiresSignature && !d.signedAt,
  ).length;

  return (
    <div className="space-y-5">
      <div className="flex flex-wrap items-center gap-3">
        <Link
          href="/equipe"
          className="text-sm font-medium text-navy/60 hover:text-navy"
        >
          ← Funcionários
        </Link>
        <Link
          href={`/equipe?tab=horas&tech=${encodeURIComponent(user.name || user.login)}`}
          className="text-sm font-medium text-navy/60 hover:text-navy"
        >
          Horas de campo
        </Link>
        <Link
          href="/documentos"
          className="text-sm font-medium text-navy/60 hover:text-navy"
        >
          Documentos RH
        </Link>
      </div>

      <PageHeader
        eyebrow="Ficha"
        title={user.name || user.login || "Funcionário"}
        description={
          pending > 0
            ? `${pending} documento(s) aguardando assinatura — o funcionário assina em Documentos RH com o login dele.`
            : "Holerites, fotos e registros anexados na mesma base do GS Campo."
        }
      />

      <section className="rounded-3xl border border-navy/10 bg-white p-5 md:p-6">
        <div className="flex flex-wrap items-start justify-between gap-3">
          <div>
            <p className="text-[11px] font-semibold uppercase tracking-[0.2em] text-brass">
              {campoRoleLabel(user.role)}
            </p>
            <p className="mt-2 text-sm text-navy/60">
              {[user.login, user.email, user.cargo, user.phone]
                .filter(Boolean)
                .join(" · ")}
            </p>
          </div>
          <div className="flex flex-wrap gap-2">
            <StatusPill
              label={user.status}
              tone={
                user.status === "aprovado"
                  ? "ok"
                  : user.status === "pendente"
                    ? "warn"
                    : "danger"
              }
            />
            <StatusPill
              label={user.active ? "Ativo" : "Inativo"}
              tone={user.active ? "ok" : "neutral"}
            />
          </div>
        </div>
        {isOffice ? (
          <div className="mt-4 border-t border-navy/8 pt-4">
            <UserAdminControls
              email={user.email}
              login={user.login}
              status={user.status}
              role={user.role}
              active={user.active}
              permissions={user.permissions}
              cargo={user.cargo}
            />
          </div>
        ) : null}
      </section>

      {isOffice && staffEmail ? (
        <StaffDocUploadForm
          staffEmail={staffEmail}
          staffName={user.name || user.login}
        />
      ) : null}

      {!staffEmail ? (
        <p className="rounded-3xl border border-dashed border-navy/15 bg-white px-4 py-10 text-center text-sm text-muted">
          Este usuário ainda não tem e-mail — cadastre o e-mail no GS Campo para
          anexar holerites.
        </p>
      ) : (
        <DocumentosBoard
          hideStaffEmail
          emptyLabel="Nenhum documento nesta ficha ainda."
          docs={docs.map((doc) => ({
            id: doc.id,
            name: doc.name,
            staffEmail: doc.staffEmail,
            kind: doc.kind,
            createdAt: doc.createdAt,
            requiresSignature: doc.requiresSignature,
            signedAt: doc.signedAt,
            signedBy: doc.signedBy,
            path: doc.path,
          }))}
        />
      )}

      {mine && !isOffice ? (
        <p className="text-sm text-navy/55">
          Para assinar holerites pendentes, use o botão{" "}
          <strong className="font-medium text-navy">Assinar</strong> nos cards
          acima ou abra{" "}
          <Link href="/documentos" className="font-semibold text-navy underline">
            Documentos RH
          </Link>
          .
        </p>
      ) : null}
    </div>
  );
}
