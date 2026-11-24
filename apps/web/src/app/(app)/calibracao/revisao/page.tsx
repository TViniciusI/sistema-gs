import Link from "next/link";
import { DataTable, PageHeader } from "@/components/ui";
import {
  kindLabel,
  listCampoOrders,
  pendingCatalogFromOrders,
} from "@/lib/campo-data";
import { CatalogReviewActions } from "./review-actions";

export const dynamic = "force-dynamic";

export default async function CatalogRevisaoPage() {
  const orders = await listCampoOrders();
  // Hidrata OS leves que possam ter slots pending no stub.
  const pendingLite = pendingCatalogFromOrders(orders);
  const needFull = orders.filter(
    (os) =>
      os.payloadLight ||
      pendingLite.some((p) => p.osId === os.id) ||
      (Array.isArray(os.raw.calibrationSlots) &&
        (os.raw.calibrationSlots as unknown[]).length > 0),
  );
  // Já temos slots no listos stub — pendingCatalogFromOrders cobre.
  const pending = pendingCatalogFromOrders(orders);

  return (
    <div>
      <PageHeader
        eyebrow="Qualidade"
        title="Revisão de cadastro"
        description="Instrumentos enviados pelo técnico com status pendente — mesmo fluxo do GS Campo."
        action={
          <Link
            href="/calibracao"
            className="rounded-xl border border-navy/15 bg-white px-4 py-2.5 text-sm font-medium text-navy"
          >
            Calibração
          </Link>
        }
      />
      <p className="mb-4 text-sm text-navy/55">
        {pending.length} pendência(s)
        {needFull.length ? ` · ${needFull.length} OS com slots` : ""}.
      </p>
      <DataTable
        headers={[
          "OS",
          "Cliente",
          "Tipo",
          "Cert.",
          "TAG",
          "N/S",
          "Equipamento",
          "Ação",
        ]}
        empty="Nenhuma submissão pendente de cadastro."
        rows={pending.map((item) => [
          <Link
            key={item.slotId}
            href={`/os/${item.osId}/certificados`}
            className="font-medium text-navy hover:underline"
          >
            GS {item.osNumber}
          </Link>,
          item.clientName || "—",
          kindLabel(item.kind),
          item.certificateNumber || "—",
          item.equipmentTag || "—",
          item.serialNumber || "—",
          [item.manufacturer, item.model].filter(Boolean).join(" ") || "—",
          <CatalogReviewActions
            key={`${item.slotId}-act`}
            osId={item.osId}
            slotId={item.slotId}
          />,
        ])}
      />
    </div>
  );
}
