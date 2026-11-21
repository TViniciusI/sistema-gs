import Link from "next/link";
import { PageHeader, Panel } from "@/components/ui";

export default function EquipamentosPage() {
  return (
    <div>
      <PageHeader
        eyebrow="Cadastros"
        title="Equipamentos"
        description="Instrumentos e presets ficam no cadastro de sistemas do cliente — igual ao app."
      />
      <Panel>
        <p className="text-sm leading-7 text-navy/70">
          Para ver TAG, N/S, medidores, PT100 e densímetros, entre no cliente e
          abra o sistema correspondente.
        </p>
        <Link
          href="/clientes"
          className="mt-4 inline-flex rounded-xl bg-navy px-4 py-2.5 text-sm font-semibold text-paper hover:bg-navy-2"
        >
          Abrir clientes e sistemas
        </Link>
      </Panel>
    </div>
  );
}
