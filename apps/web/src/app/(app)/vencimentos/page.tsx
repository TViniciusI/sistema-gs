import { DataTable, PageHeader, StatusPill } from "@/components/ui";
import { listCampoStandards } from "@/lib/campo-data";

export const dynamic = "force-dynamic";

function toneFor(validity: string): "ok" | "warn" | "danger" | "neutral" {
  const t = Date.parse(validity);
  if (!Number.isFinite(t)) return "neutral";
  const days = (t - Date.now()) / (1000 * 60 * 60 * 24);
  if (days < 0) return "danger";
  if (days < 60) return "warn";
  return "ok";
}

export default async function VencimentosPage() {
  const standards = await listCampoStandards();
  const rows = standards
    .filter((s) => s.validity)
    .sort((a, b) => Date.parse(a.validity) - Date.parse(b.validity));

  return (
    <div>
      <PageHeader
        eyebrow="Qualidade"
        title="Vencimentos"
        description="Validade dos padrões cadastrados no GS Campo."
      />
      <DataTable
        headers={["Padrão", "Tipo", "N/S", "Validade", "Situação"]}
        empty="Nenhum padrão com validade cadastrada."
        rows={rows.map((item) => {
          const tone = toneFor(item.validity);
          const label =
            tone === "danger"
              ? "Vencido"
              : tone === "warn"
                ? "A vencer"
                : "Em dia";
          return [
            item.name,
            item.type || "—",
            item.serial || "—",
            new Date(item.validity).toLocaleDateString("pt-BR"),
            <StatusPill key={item.id} label={label} tone={tone} />,
          ];
        })}
      />
    </div>
  );
}
