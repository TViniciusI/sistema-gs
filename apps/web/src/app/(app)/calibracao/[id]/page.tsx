import Link from "next/link";
import { notFound } from "next/navigation";
import { CalibWorkbenchView } from "@/components/calibracao/calib-workbench";
import { PageHeader, StatusPill } from "@/components/ui";
import {
  buildCalibrationWorkbench,
  campoAppUrl,
  getCampoCalibration,
} from "@/lib/campo-data";

export const dynamic = "force-dynamic";

function statusTone(status: string): "ok" | "warn" | "danger" | "neutral" {
  const s = status.trim().toLowerCase();
  if (s === "done") return "ok";
  if (s.includes("review") || s.includes("progress")) return "warn";
  return "neutral";
}

function statusLabel(status: string) {
  const s = status.trim().toLowerCase();
  if (s === "done") return "Concluída";
  if (s === "draft") return "Rascunho";
  if (s.includes("progress")) return "Em andamento";
  if (s.includes("review")) return "Em revisão";
  return status || "—";
}

export default async function CalibracaoDetailPage({
  params,
}: {
  params: Promise<{ id: string }>;
}) {
  const { id } = await params;
  const job = await getCampoCalibration(id);
  if (!job) notFound();

  const workbench = buildCalibrationWorkbench(job.raw);

  return (
    <div className="space-y-6">
      <PageHeader
        eyebrow="Qualidade"
        title={job.number || workbench.number || "Calibração"}
        description={
          [job.clientName || workbench.clientName, job.kind || workbench.kind]
            .filter(Boolean)
            .join(" · ") || "Job completo via getcalib"
        }
        action={
          <div className="flex flex-wrap items-center gap-2">
            <StatusPill
              label={statusLabel(job.status || workbench.status)}
              tone={statusTone(job.status || workbench.status)}
            />
            {workbench.osId ? (
              <Link
                href={`/os/${workbench.osId}`}
                className="rounded-xl border border-navy/15 bg-white px-4 py-2.5 text-sm font-medium text-navy hover:bg-paper"
              >
                OS {workbench.osNumber || ""} →
              </Link>
            ) : null}
            <a
              href={campoAppUrl()}
              target="_blank"
              rel="noreferrer"
              className="rounded-xl bg-navy px-4 py-2.5 text-sm font-semibold text-paper hover:bg-navy-2"
            >
              Abrir no Campo ↗
            </a>
            <Link
              href="/calibracao"
              className="rounded-xl border border-navy/15 bg-white px-4 py-2.5 text-sm font-medium text-navy hover:bg-paper"
            >
              Voltar
            </Link>
          </div>
        }
      />

      {!workbench.hasAny ? (
        <p className="rounded-3xl border border-dashed border-navy/15 bg-white px-4 py-12 text-center text-sm text-muted">
          Job encontrado, mas ainda sem pontos/padrões/resultados sincronizados.
          Preencha no GS Campo e sincronize.
        </p>
      ) : (
        <CalibWorkbenchView data={workbench} />
      )}
    </div>
  );
}
