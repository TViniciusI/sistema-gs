import { SYSTEM_TYPE_LABELS } from "@gs/shared";
import { PageHeader, Panel } from "@/components/ui";
import { listEquipment } from "@/lib/demo/queries";

export default function EquipamentosPage() {
  const equipment = listEquipment();

  return (
    <div>
      <PageHeader
        title="Equipamentos e instrumentos"
        description="Histórico por skid, tag e número de série — base do certificado."
      />
      <div className="space-y-4">
        {equipment.map((item) => (
          <Panel key={item.id}>
            <div className="mb-3 flex items-baseline justify-between gap-3">
              <h2 className="font-serif text-lg text-navy">{item.tag}</h2>
              <span className="text-sm text-muted">
                {item.location?.alias} · {SYSTEM_TYPE_LABELS[item.systemType]}
              </span>
            </div>
            <table className="w-full text-left text-sm">
              <thead className="text-xs uppercase tracking-wide text-muted">
                <tr>
                  <th className="py-1 font-medium">Tag</th>
                  <th className="font-medium">Instrumento</th>
                  <th className="font-medium">Fabricante</th>
                  <th className="font-medium">Série</th>
                </tr>
              </thead>
              <tbody>
                {item.instruments.map((instrument) => (
                  <tr key={instrument.tag} className="border-t border-line">
                    <td className="py-2">{instrument.tag}</td>
                    <td>{instrument.kind}</td>
                    <td>{instrument.manufacturer}</td>
                    <td>{instrument.serial}</td>
                  </tr>
                ))}
              </tbody>
            </table>
          </Panel>
        ))}
      </div>
    </div>
  );
}
