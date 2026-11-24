import Link from "next/link";
import { PageHeader, Panel } from "@/components/ui";
import { campoAppUrl } from "@/lib/campo-data";

export default function NovoEquipePage() {
  return (
    <div>
      <PageHeader
        title="Novo integrante"
        description="Aprovação e papéis ficam na planilha do GS Campo — não no cadastro demo."
      />
      <Panel>
        <p className="text-sm leading-6 text-navy/70">
          Use o app de campo (ou a aba de usuários do gate) para cadastrar /
          aprovar funcionários. O escritório lista o mesmo time e as horas de
          RDO.
        </p>
        <div className="mt-5 flex flex-wrap gap-2">
          <a
            href={campoAppUrl()}
            target="_blank"
            rel="noreferrer"
            className="rounded-xl bg-navy px-4 py-2.5 text-sm font-semibold text-paper hover:bg-navy-2"
          >
            Abrir GS Campo ↗
          </a>
          <Link
            href="/equipe"
            className="rounded-xl border border-navy/15 bg-paper px-4 py-2.5 text-sm font-medium text-navy hover:border-brass/40"
          >
            Voltar à equipe
          </Link>
        </div>
      </Panel>
    </div>
  );
}
