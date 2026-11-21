import Link from "next/link";
import { PageHeader, Panel } from "@/components/ui";

export default function LocaisPage() {
  return (
    <div>
      <PageHeader
        eyebrow="Cadastros"
        title="Locais e bases"
        description="No GS Campo, bases e plataformas ficam dentro do cadastro do cliente."
      />
      <Panel>
        <p className="text-sm leading-7 text-navy/70">
          Abra um cliente para ver sistemas, plataformas de carregamento e
          equipamentos no mesmo lugar do app.
        </p>
        <Link
          href="/clientes"
          className="mt-4 inline-flex rounded-xl bg-navy px-4 py-2.5 text-sm font-semibold text-paper hover:bg-navy-2"
        >
          Ir para clientes e sistemas
        </Link>
      </Panel>
    </div>
  );
}
