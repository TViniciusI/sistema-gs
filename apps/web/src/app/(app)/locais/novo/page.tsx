import Link from "next/link";
import { PageHeader, Panel } from "@/components/ui";
import { campoAppUrl } from "@/lib/campo-data";

export default function NovoLocalPage() {
  return (
    <div>
      <PageHeader
        title="Novo local"
        description="Locais e bases do cliente são cadastrados no GS Campo."
      />
      <Panel>
        <p className="text-sm leading-6 text-navy/70">
          O formulário demo foi desativado. Cadastre o local no app; no
          escritório os dados vêm da mesma planilha.
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
            href="/clientes"
            className="rounded-xl border border-navy/15 bg-paper px-4 py-2.5 text-sm font-medium text-navy hover:border-brass/40"
          >
            Clientes
          </Link>
        </div>
      </Panel>
    </div>
  );
}
