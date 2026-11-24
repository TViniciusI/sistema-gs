import Link from "next/link";
import { CalibEditor } from "@/components/calibracao/calib-editor";
import { PageHeader } from "@/components/ui";
import { listCampoStandards, newCalibrationId } from "@/lib/campo-data";

export const dynamic = "force-dynamic";

export default async function NovaCalibracaoPage() {
  const standards = await listCampoStandards();
  const id = newCalibrationId();

  const initial: Record<string, unknown> = {
    id,
    number: "",
    kind: "volumetric",
    status: "draft",
    clientName: "",
    equipmentTag: "",
    equipmentType: "",
    manufacturer: "",
    model: "",
    serialNumber: "",
    technicianName: "",
    calibrationDate: new Date().toISOString().slice(0, 10),
    nextCalibrationDate: "",
    site: "",
    fluid: "",
    ambientTemp: "",
    humidity: "",
    pressure: "",
    meterKFactorFound: "",
    meterKFactorLeft: "",
    measurementUncertainty: "",
    coverageFactor: "2",
    effectiveDof: "",
    points: [],
    standards: [],
  };

  return (
    <div className="space-y-6">
      <PageHeader
        eyebrow="Qualidade"
        title="Nova calibração"
        description="Mesma planilha do GS Campo — ao salvar, o app recebe no sync (savecalib)."
        action={
          <Link
            href="/calibracao"
            className="rounded-xl border border-navy/15 bg-white px-4 py-2.5 text-sm font-medium text-navy hover:bg-paper"
          >
            Voltar
          </Link>
        }
      />
      <CalibEditor
        initial={initial}
        catalogStandards={standards}
        isNew
      />
    </div>
  );
}
