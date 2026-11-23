import Link from "next/link";
import { notFound } from "next/navigation";
import { PageHeader, StatusPill } from "@/components/ui";
import { getCampoOrder } from "@/lib/campo-data";
import {
  campoOsStatusLabel,
  campoOsStatusTone,
} from "@/lib/campo-data/labels";

export const dynamic = "force-dynamic";

function text(value: unknown) {
  return typeof value === "string" ? value.trim() : "";
}

export default async function OsDetailPage({
  params,
}: {
  params: Promise<{ id: string }>;
}) {
  const { id } = await params;
  const os = await getCampoOrder(id);
  if (!os) notFound();

  const rdo = (
    os.raw.rdo && typeof os.raw.rdo === "object" ? os.raw.rdo : {}
  ) as Record<string, unknown>;
  const rdos = Array.isArray(os.raw.rdos) ? os.raw.rdos : [];
  const files = Array.isArray(os.raw.files) ? os.raw.files : [];
  const slots = Array.isArray(os.raw.calibrationSlots)
    ? os.raw.calibrationSlots
    : [];

  const service = text(rdo.service) || "—";
  const systemType = text(rdo.systemType) || "—";
  const site =
    text(rdo.site) ||
    [rdo.city, rdo.state].filter(Boolean).join("/") ||
    text(rdo.baseName) ||
    "—";

  return (
    <div className="space-y-6">
      <PageHeader
        eyebrow="Operação"
        title={`OS GS ${os.number}`}
        description={os.clientName || "Ordem de serviço GS Campo"}
        action={
          <div className="flex flex-wrap items-center gap-2">
            <StatusPill
              label={campoOsStatusLabel(os.status)}
              tone={campoOsStatusTone(os.status)}
            />
            <Link
              href="/os"
              className="rounded-xl border border-navy/15 bg-white px-4 py-2.5 text-sm font-medium text-navy hover:bg-paper"
            >
              Voltar
            </Link>
          </div>
        }
      />

      <div className="grid gap-4 lg:grid-cols-3">
        <section className="rounded-3xl border border-navy/10 bg-navy px-5 py-5 text-paper lg:col-span-1">
          <p className="text-[11px] font-semibold uppercase tracking-[0.22em] text-brass">
            Resumo
          </p>
          <dl className="mt-4 space-y-3 text-sm">
            <div>
              <dt className="text-paper/45">Cliente</dt>
              <dd className="mt-0.5 font-medium">
                {os.clientName || text(rdo.client) || "—"}
              </dd>
            </div>
            <div>
              <dt className="text-paper/45">CNPJ</dt>
              <dd className="mt-0.5">{text(rdo.cnpj) || "—"}</dd>
            </div>
            <div>
              <dt className="text-paper/45">Início</dt>
              <dd className="mt-0.5">
                {os.startsAt
                  ? new Date(os.startsAt).toLocaleString("pt-BR")
                  : "—"}
              </dd>
            </div>
            <div>
              <dt className="text-paper/45">Técnicos</dt>
              <dd className="mt-0.5">{os.technicianName || "—"}</dd>
            </div>
          </dl>
        </section>

        <section className="rounded-3xl border border-navy/10 bg-white px-5 py-5 lg:col-span-2">
          <p className="text-[11px] font-semibold uppercase tracking-[0.22em] text-brass">
            Serviço
          </p>
          <div className="mt-4 grid gap-4 sm:grid-cols-2">
            {[
              ["Serviço contratado", service],
              ["Tipo de sistema", systemType],
              ["Local", site],
              ["Responsável base", text(rdo.baseName) || "—"],
            ].map(([label, value]) => (
              <div key={label}>
                <p className="text-xs uppercase tracking-wide text-muted">
                  {label}
                </p>
                <p className="mt-1 text-sm font-medium text-navy">{value}</p>
              </div>
            ))}
          </div>
        </section>
      </div>

      <div className="grid gap-4 sm:grid-cols-3">
        {[
          { label: "RDOs", value: String(rdos.length) },
          { label: "Arquivos", value: String(files.length) },
          { label: "Calibração", value: String(slots.length) },
        ].map((item) => (
          <div
            key={item.label}
            className="rounded-2xl border border-navy/10 bg-white px-4 py-4"
          >
            <p className="text-[11px] font-semibold uppercase tracking-[0.18em] text-navy/45">
              {item.label}
            </p>
            <p className="mt-2 font-serif text-3xl text-navy">{item.value}</p>
          </div>
        ))}
      </div>

      {rdos.length > 0 ? (
        <section className="rounded-3xl border border-navy/10 bg-white p-5">
          <h2 className="font-serif text-xl text-navy">RDOs de campo</h2>
          <div className="mt-4 divide-y divide-navy/8 overflow-hidden rounded-2xl border border-navy/8">
            {rdos.map((item, index) => {
              const entry =
                item && typeof item === "object"
                  ? (item as Record<string, unknown>)
                  : {};
              const day = text(entry.date) || text(entry.day);
              return (
                <div
                  key={String(entry.id || index)}
                  className="px-4 py-3 text-sm"
                >
                  <div className="font-medium text-navy">
                    RDO{" "}
                    {day
                      ? new Date(day).toLocaleDateString("pt-BR")
                      : index + 1}
                  </div>
                  <div className="text-muted">
                    {text(entry.description) ||
                      text(entry.obs) ||
                      "Registro de campo"}
                  </div>
                </div>
              );
            })}
          </div>
        </section>
      ) : null}

      <div className="rounded-2xl border border-navy/10 bg-white/80 px-4 py-3 text-sm text-navy/60">
        RDO, fotos e anexos continuam no app de campo.{" "}
        <Link href="/arquivos" className="font-medium text-navy underline">
          Ver arquivos no escritório
        </Link>
        .
      </div>
    </div>
  );
}
