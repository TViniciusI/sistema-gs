import Link from "next/link";
import { notFound } from "next/navigation";
import { formatCnpj } from "@gs/shared";
import { PageHeader, Panel } from "@/components/ui";
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

  return (
    <div>
      <PageHeader
        title={client.name}
        description={
          client.cnpj
            ? `CNPJ ${formatCnpj(client.cnpj)} · cadastro GS Campo`
            : "Cadastro GS Campo"
        }
      />

      <div className="mb-4">
        <Link href="/clientes" className="text-sm text-navy/60 hover:text-navy">
          ← Voltar aos clientes
        </Link>
      </div>

      <div className="grid gap-4 lg:grid-cols-[minmax(0,0.9fr)_minmax(0,1.3fr)]">
        <div className="space-y-4">
          <Panel>
            <h2 className="mb-3 font-serif text-lg text-navy">Dados</h2>
            <dl className="space-y-3 text-sm">
              <div>
                <dt className="text-muted">CNPJ</dt>
                <dd>{client.cnpj ? formatCnpj(client.cnpj) : "—"}</dd>
              </div>
              <div>
                <dt className="text-muted">Solicitante</dt>
                <dd>{client.requester || "—"}</dd>
              </div>
              <div>
                <dt className="text-muted">Cidade</dt>
                <dd>
                  {[client.city, client.state].filter(Boolean).join("/") || "—"}
                </dd>
              </div>
              <div>
                <dt className="text-muted">Responsável da base</dt>
                <dd>
                  {client.baseName || "—"}
                  {client.baseCargo ? ` · ${client.baseCargo}` : ""}
                  <br />
                  {[client.basePhone, client.baseEmail]
                    .filter(Boolean)
                    .join(" · ") || null}
                </dd>
              </div>
              {client.sites.length > 0 ? (
                <div>
                  <dt className="text-muted">Bases / sites</dt>
                  <dd>{client.sites.join(", ")}</dd>
                </div>
              ) : null}
            </dl>
          </Panel>

          <Panel>
            <h2 className="mb-3 font-serif text-lg text-navy">Editar cadastro</h2>
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
          </Panel>
        </div>

        <div className="space-y-4">
          <div className="flex items-end justify-between gap-3">
            <div>
              <h2 className="font-serif text-lg text-navy">
                Sistemas e instrumentos
              </h2>
              <p className="mt-1 text-sm text-muted">
                Fonte da verdade da planilha — exclusões aqui atualizam o GS
                Campo após o sync do aparelho.
              </p>
            </div>
            <p className="text-sm text-navy/50">
              {client.systems.length} conjunto(s)
            </p>
          </div>

          {client.systems.length === 0 ? (
            <Panel>
              <p className="text-sm text-muted">
                Nenhum sistema neste cliente
                {client.payloadLight ? " (resumo incompleto no Drive)." : "."}
              </p>
            </Panel>
          ) : (
            [...grouped.entries()].map(([type, systems]) => (
              <section key={type} className="space-y-3">
                <h3 className="text-[11px] font-semibold uppercase tracking-[0.18em] text-brass">
                  {type}
                </h3>
                {systems.map((system) => {
                  const title = systemTitle(system);
                  const crumb = [
                    system.systemType,
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
                      className="rounded-xl border border-line bg-white px-5 py-4 shadow-[0_1px_0_rgba(12,31,51,0.04)]"
                    >
                      <div className="flex items-start justify-between gap-3">
                        <div className="min-w-0">
                          <h4 className="font-serif text-xl text-navy">
                            {system.systemType || title}
                          </h4>
                          <p className="mt-1 text-sm text-muted">{crumb}</p>
                          <p className="mt-3 text-[15px] font-medium text-navy">
                            {title}
                          </p>
                          <p className="mt-1 text-sm leading-6 text-navy/70">
                            {systemMeta(system) || "Sem detalhes cadastrados."}
                          </p>
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
                                    {[kind, tag && `TAG ${tag}`, serial && `N/S ${serial}`]
                                      .filter(Boolean)
                                      .join(" · ") || "Instrumento"}
                                  </li>
                                );
                              })}
                            </ul>
                          ) : null}
                        </div>
                        <DeleteSystemButton
                          clientId={client.id}
                          systemId={system.id}
                          label={title}
                        />
                      </div>
                    </article>
                  );
                })}
              </section>
            ))
          )}
        </div>
      </div>
    </div>
  );
}
