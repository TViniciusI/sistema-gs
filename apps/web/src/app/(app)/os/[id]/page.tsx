import { notFound } from "next/navigation";
import Link from "next/link";
import {
  SERVICE_TYPE_LABELS,
  SYSTEM_TYPE_LABELS,
  TECHNICIAN_FUNCTION_LABELS,
  WORK_ORDER_STATUS_LABELS,
  canTransition,
  formatWorkOrderNumber,
  type WorkOrderStatus,
} from "@gs/shared";
import { Button, PageHeader, Panel } from "@/components/ui";
import { getWorkOrder, listCertificates, technicianName } from "@/lib/demo/queries";
import { updateWorkOrderStatus } from "../actions";

export default async function OsDetailPage({
  params,
}: {
  params: Promise<{ id: string }>;
}) {
  const { id } = await params;
  const os = getWorkOrder(id);
  if (!os) notFound();

  const certificate = listCertificates().find((item) => item.workOrderId === os.id);
  const title = formatWorkOrderNumber(os.number, os.year);

  return (
    <div>
      <PageHeader
        title={title}
        description={`${os.client?.legalName} · ${os.location?.alias}`}
      />

      <div className="grid gap-4 lg:grid-cols-3">
        <Panel>
          <h2 className="mb-3 font-serif text-lg text-navy">Serviço</h2>
          <dl className="space-y-2 text-sm">
            <Row label="OC" value={os.purchaseOrder} />
            <Row label="Serviço" value={SERVICE_TYPE_LABELS[os.serviceType]} />
            <Row label="Sistema" value={SYSTEM_TYPE_LABELS[os.systemType]} />
            <Row
              label="Data"
              value={new Date(`${os.scheduledDate}T00:00:00`).toLocaleDateString("pt-BR")}
            />
            <Row label="Endereço" value={os.location?.address} />
            <Row label="Status" value={WORK_ORDER_STATUS_LABELS[os.status]} />
          </dl>
          <div className="mt-4 flex flex-wrap gap-2">
            {(
              [
                "accepted",
                "traveling",
                "on_site",
                "in_progress",
                "awaiting_signature",
                "completed",
                "reviewed",
              ] as WorkOrderStatus[]
            )
              .filter((status) => canTransition(os.status, status))
              .map((status) => (
                <form key={status} action={updateWorkOrderStatus}>
                  <input type="hidden" name="work_order_id" value={os.id} />
                  <input type="hidden" name="status" value={status} />
                  <Button type="submit" variant="ghost">
                    {WORK_ORDER_STATUS_LABELS[status]}
                  </Button>
                </form>
              ))}
          </div>
        </Panel>
        <Panel>
          <h2 className="mb-3 font-serif text-lg text-navy">Equipe em campo</h2>
          <ul className="space-y-2 text-sm">
            {os.team.map((member) => (
              <li key={member.technicianId}>
                <span className="font-medium">
                  {technicianName(member.technicianId)}
                </span>
                <span className="text-muted">
                  {" "}
                  · {TECHNICIAN_FUNCTION_LABELS[member.function]}
                  {member.owner ? " · responsável" : ""}
                </span>
              </li>
            ))}
          </ul>
        </Panel>
        <Panel>
          <h2 className="mb-3 font-serif text-lg text-navy">Cliente no local</h2>
          <p className="text-sm">
            {os.client?.manager.name}
            <br />
            <span className="text-muted">{os.client?.manager.title}</span>
          </p>
          {os.signature ? (
            <div className="mt-4 border-t border-line pt-3">
              <div className="text-xs uppercase tracking-wide text-muted">
                Assinatura coletada
              </div>
              <div className="mt-2 h-16 rounded-sm border border-dashed border-brass bg-paper px-3 py-2 font-serif italic text-navy">
                {os.signature.name}
              </div>
              <div className="mt-1 text-xs text-muted">
                {os.signature.role} ·{" "}
                {new Date(os.signature.at).toLocaleString("pt-BR")}
              </div>
            </div>
          ) : (
            <p className="mt-4 text-sm text-muted">Aguardando assinatura.</p>
          )}
          {certificate ? (
            <div className="mt-4">
              <Link
                href={`/certificados/${certificate.id}`}
                className="text-sm text-navy underline"
              >
                Ver certificado {certificate.number}
              </Link>
            </div>
          ) : null}
        </Panel>
      </div>

      <div className="mt-4 grid gap-4 lg:grid-cols-2">
        <Panel>
          <h2 className="mb-3 font-serif text-lg text-navy">Registro do dia (RDO)</h2>
          {os.timeEntries.length === 0 ? (
            <p className="text-sm text-muted">Nenhum lançamento ainda.</p>
          ) : (
            <ul className="space-y-4 text-sm">
              {os.timeEntries.map((entry) => (
                <li key={entry.id} className="border-b border-line pb-3 last:border-0">
                  <div className="font-medium">
                    {new Date(`${entry.date}T00:00:00`).toLocaleDateString("pt-BR")}{" "}
                    · {technicianName(entry.technicianId)}
                  </div>
                  <div className="mt-1 text-muted">
                    Entrada {entry.clockIn} · Almoço {entry.lunchStart}–
                    {entry.lunchEnd} · Saída {entry.clockOut}
                  </div>
                  <p className="mt-2">{entry.description}</p>
                </li>
              ))}
            </ul>
          )}
        </Panel>
        <Panel>
          <h2 className="mb-3 font-serif text-lg text-navy">Linha do tempo + GPS</h2>
          <ul className="space-y-3 text-sm">
            {os.events.map((event, index) => (
              <li key={index}>
                <div className="flex justify-between gap-3">
                  <span className="font-medium">{event.type}</span>
                  <span className="text-muted">
                    {new Date(event.at).toLocaleString("pt-BR")}
                  </span>
                </div>
                <div className="text-muted">{event.detail}</div>
                {event.lat ? (
                  <div className="text-xs text-brass">
                    {event.lat.toFixed(4)}, {event.lng?.toFixed(4)}
                  </div>
                ) : null}
              </li>
            ))}
          </ul>
        </Panel>
      </div>

      <div className="mt-4">
        <Panel>
          <h2 className="mb-3 font-serif text-lg text-navy">Evidências fotográficas</h2>
          {os.photos.length === 0 ? (
            <p className="text-sm text-muted">Nenhuma foto nesta OS.</p>
          ) : (
            <div className="grid gap-3 sm:grid-cols-4">
              {os.photos.map((photo) => (
                <div
                  key={photo.id}
                  className="flex aspect-square items-end rounded-sm border border-line bg-navy p-3 text-xs text-paper"
                >
                  {photo.caption}
                </div>
              ))}
            </div>
          )}
        </Panel>
      </div>
    </div>
  );
}

function Row({ label, value }: { label: string; value?: string | null }) {
  return (
    <div>
      <dt className="text-muted">{label}</dt>
      <dd>{value || "—"}</dd>
    </div>
  );
}
