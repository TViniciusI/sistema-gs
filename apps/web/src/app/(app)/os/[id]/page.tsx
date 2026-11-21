import Link from "next/link";
import { notFound } from "next/navigation";
import { PageHeader, Panel, StatusPill } from "@/components/ui";
import { getCampoOrder } from "@/lib/campo-data";
import {
  campoOsStatusLabel,
  campoOsStatusTone,
} from "@/lib/campo-data/labels";

export const dynamic = "force-dynamic";

export default async function OsDetailPage({
  params,
}: {
  params: Promise<{ id: string }>;
}) {
  const { id } = await params;
  const os = await getCampoOrder(id);
  if (!os) notFound();

  const rdo = (os.raw.rdo && typeof os.raw.rdo === "object"
    ? os.raw.rdo
    : {}) as Record<string, unknown>;
  const rdos = Array.isArray(os.raw.rdos) ? os.raw.rdos : [];
  const files = Array.isArray(os.raw.files) ? os.raw.files : [];
  const slots = Array.isArray(os.raw.calibrationSlots)
    ? os.raw.calibrationSlots
    : [];

  return (
    <div>
      <PageHeader
        title={`OS GS ${os.number}`}
        description={os.clientName || "Ordem de serviço GS Campo"}
        action={
          <StatusPill
            label={campoOsStatusLabel(os.status)}
            tone={campoOsStatusTone(os.status)}
          />
        }
      />

      <div className="mb-4">
        <Link href="/os" className="text-sm text-navy/60 hover:text-navy">
          ← Voltar às OS
        </Link>
      </div>

      <div className="grid gap-4 lg:grid-cols-2">
        <Panel>
          <h2 className="mb-3 font-serif text-lg text-navy">Resumo</h2>
          <dl className="space-y-2 text-sm">
            <div>
              <dt className="text-muted">Cliente</dt>
              <dd>{os.clientName || String(rdo.client || "—")}</dd>
            </div>
            <div>
              <dt className="text-muted">CNPJ</dt>
              <dd>{String(rdo.cnpj || "—")}</dd>
            </div>
            <div>
              <dt className="text-muted">Local</dt>
              <dd>
                {[rdo.city, rdo.state].filter(Boolean).join("/") ||
                  String(rdo.baseName || "—")}
              </dd>
            </div>
            <div>
              <dt className="text-muted">Técnicos</dt>
              <dd>{os.technicianName || "—"}</dd>
            </div>
            <div>
              <dt className="text-muted">Início</dt>
              <dd>
                {os.startsAt
                  ? new Date(os.startsAt).toLocaleString("pt-BR")
                  : "—"}
              </dd>
            </div>
          </dl>
        </Panel>

        <Panel>
          <h2 className="mb-3 font-serif text-lg text-navy">Campo</h2>
          <dl className="space-y-2 text-sm">
            <div>
              <dt className="text-muted">RDOs</dt>
              <dd>{rdos.length}</dd>
            </div>
            <div>
              <dt className="text-muted">Arquivos anexos</dt>
              <dd>{files.length}</dd>
            </div>
            <div>
              <dt className="text-muted">Slots de calibração</dt>
              <dd>{slots.length}</dd>
            </div>
            <div>
              <dt className="text-muted">Pasta Drive</dt>
              <dd>
                <Link href="/arquivos" className="text-navy hover:underline">
                  Ver arquivos do escritório
                </Link>
              </dd>
            </div>
          </dl>
        </Panel>
      </div>

      {rdos.length > 0 ? (
        <section className="mt-6">
          <h2 className="mb-3 font-serif text-lg text-navy">RDOs</h2>
          <div className="divide-y divide-line border border-line bg-white">
            {rdos.map((item, index) => {
              const entry =
                item && typeof item === "object"
                  ? (item as Record<string, unknown>)
                  : {};
              const day = String(entry.date || entry.day || "");
              return (
                <div key={String(entry.id || index)} className="px-5 py-3 text-sm">
                  <div className="font-medium text-navy">
                    RDO {day ? new Date(day).toLocaleDateString("pt-BR") : index + 1}
                  </div>
                  <div className="text-muted">
                    {String(entry.description || entry.obs || "Registro de campo")}
                  </div>
                </div>
              );
            })}
          </div>
        </section>
      ) : null}
    </div>
  );
}
