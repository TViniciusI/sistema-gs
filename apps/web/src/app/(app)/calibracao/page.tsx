import Link from "next/link";
import { DataTable, PageHeader, StatusPill } from "@/components/ui";
import { listCampoCalibrations } from "@/lib/campo-data";

export const dynamic = "force-dynamic";

export default async function CalibracaoPage() {
  const items = await listCampoCalibrations();

  return (
    <div>
      <PageHeader
        eyebrow="Qualidade"
        title="Calibração"
        description="Mesmos trabalhos de calibração gravados pelo GS Campo."
        action={
          <Link
            href="/calibracao/revisao"
            className="rounded-xl bg-brass px-4 py-2.5 text-sm font-semibold text-navy hover:bg-brass-2"
          >
            Revisão de cadastro
          </Link>
        }
      />
      <DataTable
        headers={["Nº", "Cliente", "Equipamento", "Tipo", "Atualizado", "Status"]}
        empty="Nenhuma calibração na planilha."
        rows={items.slice(0, 200).map((item) => [
          <Link
            key={item.id}
            href={`/certificados?calib=${item.id}`}
            className="font-medium text-navy hover:underline"
          >
            {item.number}
          </Link>,
          item.clientName || "—",
          [item.equipmentTag, item.equipmentType].filter(Boolean).join(" · ") ||
            "—",
          item.kind || "—",
          item.updatedAt
            ? new Date(item.updatedAt).toLocaleDateString("pt-BR")
            : "—",
          <StatusPill key={`${item.id}-st`} label={item.status} tone="neutral" />,
        ])}
      />
      {items.length > 200 ? (
        <p className="mt-3 text-sm text-muted">
          Mostrando 200 de {items.length} registros.
        </p>
      ) : null}
    </div>
  );
}
