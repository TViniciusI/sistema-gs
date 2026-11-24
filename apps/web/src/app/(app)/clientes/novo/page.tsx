import Link from "next/link";
import { PageHeader, Panel } from "@/components/ui";
import { campoAppUrl } from "@/lib/campo-data";

export default function NovoClientePage() {
  return (
    <div>
      <PageHeader
        title="Novo cliente"
        description="Cadastro completo fica no GS Campo (mesma planilha do escritório)."
      />
      <Panel>
        <p className="text-sm leading-6 text-navy/70">
          O formulário demo local foi desativado para não gravar cliente fora da
          fonte da verdade. Crie ou edite o cliente no app de campo; aqui você
          consulta e remove sistemas.
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
            Voltar aos clientes
          </Link>
        </div>
      </Panel>
    </div>
  );
}
