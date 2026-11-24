import Link from "next/link";
import { notFound } from "next/navigation";
import { formatCnpj } from "@gs/shared";
import { PageHeader } from "@/components/ui";
import { getCampoClient } from "@/lib/campo-data";
import { kindLabel } from "@/lib/campo-data/labels";
import { DeleteSystemButton } from "../delete-system-button";
import { ClientEditForm } from "./edit-form";

export const dynamic = "force-dynamic";

function systemTitle(system: {
  kind: string;
  tag: string;
  assemblyTag: string;
}): string {
  const kind = kindLabel(system.kind);
  const tag = system.assemblyTag || system.tag;
  return tag ? `${kind} ${tag}` : kind;
}

function systemMeta(system: {
  meterCount: number;
  pt100Count: number;
  meshCount: number;
  densimeterCount: number;
  manufacturer: string;
  model: string;
  serialNumber: string;
}): string {
  const parts: string[] = [];
  const make = [system.manufacturer, system.model].filter(Boolean).join(" ");
  if (make) parts.push(make);
  if (system.serialNumber) parts.push(`N/S ${system.serialNumber}`);
  if (system.meterCount) parts.push(`${system.meterCount} medidor(es)`);
  if (system.pt100Count) parts.push(`${system.pt100Count} PT100`);
  if (system.meshCount) parts.push(`${system.meshCount} malha(s)`);
  if (system.densimeterCount) {
    parts.push(`${system.densimeterCount} densímetro(s)`);
  }
  return parts.join(" · ");
}

function instrumentsForSystem(
  equipment: unknown[],
  systemId: string,
  systemInstruments: unknown[] | undefined,
) {
  const fromSystem = Array.isArray(systemInstruments) ? systemInstruments : [];
  const fromEquipment = equipment.filter((item) => {
    if (!item || typeof item !== "object") return false;
    return String((item as Record<string, unknown>).systemId ?? "") === systemId;
  });
  return [...fromSystem, ...fromEquipment];
}

export default async function ClienteDetailPage({
  params,
}: {
  params: Promise<{ id: string }>;
}) {
  const { id } = await params;
  const client = await getCampoClient(id);
  if (!client) notFound();

  const grouped = new Map<string, typeof client.systems>();
  for (const system of client.systems) {
    const key = system.systemType || "Sem tipo";
    const list = grouped.get(key) ?? [];
    list.push(system);
    grouped.set(key, list);
  }

  const place =
    [client.city, client.state].filter(Boolean).join("/") || "—";
  const baseLine = [
    client.baseName,
    client.baseCargo,
    client.basePhone,
    client.baseEmail,
  ]
    .filter(Boolean)
    .join(" · ");

  return (
    <div className="space-y-6">
      <PageHeader
        eyebrow="Cadastros"
        title={client.name || "Cliente"}
        description={
          client.cnpj
            ? `CNPJ ${formatCnpj(client.cnpj)} · cadastro GS Campo`
            : "Cadastro GS Campo"
        }
        action={
          <div className="flex flex-wrap items-center gap-2">
            {client.payloadLight ? (
              <span className="rounded-full bg-warn/15 px-3 py-1 text-[11px] font-semibold uppercase tracking-wide text-warn">
                Resumo
              </span>
            ) : null}
            <Link
              href="/clientes"
              className="rounded-xl border border-navy/15 bg-white px-4 py-2.5 text-sm font-medium text-navy hover:bg-paper"
            >
              Voltar
            </Link>
          </div>
        }
      />

      <section className="rounded-3xl border border-navy/10 bg-white p-5 md:p-6">
        <p className="text-[11px] font-semibold uppercase tracking-[0.22em] text-brass">
          Resumo
        </p>
        <div className="mt-4 grid gap-3 sm:grid-cols-2 lg:grid-cols-4">
          <div className="rounded-2xl bg-paper px-4 py-3">
            <p className="text-[10px] uppercase tracking-wide text-navy/45">
              Cidade
            </p>
            <p className="mt-1 text-sm font-medium text-navy">{place}</p>
          </div>
          <div className="rounded-2xl bg-paper px-4 py-3">
            <p className="text-[10px] uppercase tracking-wide text-navy/45">
              Solicitante
            </p>
            <p className="mt-1 text-sm font-medium text-navy">
              {client.requester || "—"}
            </p>
          </div>
          <div className="rounded-2xl bg-paper px-4 py-3">
            <p className="text-[10px] uppercase tracking-wide text-navy/45">
              Base
            </p>
            <p className="mt-1 text-sm font-medium text-navy">
              {baseLine || "—"}
            </p>
          </div>
          <div className="rounded-2xl bg-paper px-4 py-3">
            <p className="text-[10px] uppercase tracking-wide text-navy/45">
              Sistemas
            </p>
            <p className="mt-1 text-sm font-medium text-navy">
              {client.payloadLight
                ? "Abrir carregou resumo"
                : `${client.systems.length} conjunto(s)`}
            </p>
          </div>
        </div>
        {client.sites.length > 0 ? (
          <p className="mt-4 text-sm text-navy/55">
            Sites: {client.sites.join(", ")}
          </p>
        ) : null}
      </section>

      <section className="rounded-3xl border border-navy/10 bg-white p-5 md:p-6">
        <p className="text-[11px] font-semibold uppercase tracking-[0.22em] text-brass">
          Cadastro
        </p>
        <h2 className="mt-1 font-serif text-xl text-navy">Editar dados</h2>
        <p className="mt-2 mb-4 text-sm text-navy/55">
          Contato e base — grava na mesma planilha do GS Campo.
        </p>
        <ClientEditForm
          clientId={client.id}
          defaults={{
            name: client.name,
            requester: client.requester,
            city: client.city,
            state: client.state,
            baseName: client.baseName,
            baseCargo: client.baseCargo,
            baseEmail: client.baseEmail,
            basePhone: client.basePhone,
            sites: client.sites.join("|"),
          }}
        />
      </section>

      <section className="space-y-4">
        <div className="flex flex-wrap items-end justify-between gap-3">
          <div>
            <p className="text-[11px] font-semibold uppercase tracking-[0.22em] text-brass">
              Equipamentos
            </p>
            <h2 className="mt-1 font-serif text-xl text-navy">
              Sistemas e instrumentos
            </h2>
            <p className="mt-1 text-sm text-navy/55">
              Exclusões aqui atualizam a planilha e o GS Campo após o sync.
            </p>
          </div>
          <p className="text-sm text-navy/50">
            {client.systems.length} conjunto(s)
          </p>
        </div>

        {client.systems.length === 0 ? (
          <div className="rounded-3xl border border-dashed border-navy/15 bg-white px-4 py-12 text-center text-sm text-muted">
            Nenhum sistema neste cliente
            {client.payloadLight ? " (resumo incompleto no Drive)." : "."}
          </div>
        ) : (
          [...grouped.entries()].map(([type, systems]) => (
            <div key={type} className="space-y-3">
              <h3 className="text-[11px] font-semibold uppercase tracking-[0.18em] text-brass">
                {type} · {systems.length}
              </h3>
              <div className="grid gap-3 lg:grid-cols-2">
                {systems.map((system) => {
                  const title = systemTitle(system);
                  const crumb = [
                    system.installLocation,
                    kindLabel(system.kind),
                  ]
                    .filter(Boolean)
                    .join(" · ");
                  const instruments = instrumentsForSystem(
                    Array.isArray(client.equipment) ? client.equipment : [],
                    system.id,
                    system.instruments,
                  );
                  return (
                    <article
                      key={system.id}
                      className="rounded-2xl border border-navy/10 bg-white p-4 shadow-[0_8px_24px_rgba(12,31,51,0.04)]"
                    >
                      <div className="flex items-start justify-between gap-3">
                        <div className="min-w-0">
                          <h4 className="font-serif text-lg text-navy">
                            {title}
                          </h4>
                          {crumb ? (
                            <p className="mt-1 text-xs text-navy/45">{crumb}</p>
                          ) : null}
                          <p className="mt-2 text-sm leading-6 text-navy/70">
                            {systemMeta(system) || "Sem detalhes cadastrados."}
                          </p>
                        </div>
                        <DeleteSystemButton
                          clientId={client.id}
                          systemId={system.id}
                          label={title}
                        />
                      </div>
                      {instruments.length > 0 ? (
                        <ul className="mt-3 space-y-1.5 border-t border-navy/8 pt-3 text-sm text-navy/75">
                          {instruments.map((raw, index) => {
                            const item =
                              raw && typeof raw === "object"
                                ? (raw as Record<string, unknown>)
                                : {};
                            const tag = String(
                              item.tag || item.equipmentTag || "",
                            );
                            const serial = String(
                              item.serialNumber || item.serial || "",
                            );
                            const kind = String(
                              item.kind || item.equipmentType || "",
                            );
                            return (
                              <li key={`${system.id}-eq-${index}`}>
                                {[
                                  kind,
                                  tag && `TAG ${tag}`,
                                  serial && `N/S ${serial}`,
                                ]
                                  .filter(Boolean)
                                  .join(" · ") || "Instrumento"}
                              </li>
                            );
                          })}
                        </ul>
                      ) : null}
                    </article>
                  );
                })}
              </div>
            </div>
          ))
        )}
      </section>
    </div>
  );
}
