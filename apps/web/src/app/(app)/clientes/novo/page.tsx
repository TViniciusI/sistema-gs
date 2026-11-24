import Link from "next/link";
import { ClientCreateForm } from "@/components/clientes/client-create-form";
import { PageHeader } from "@/components/ui";

export default function NovoClientePage() {
  return (
    <div className="space-y-6">
      <PageHeader
        eyebrow="Cadastros"
        title="Novo cliente"
        description="Grava na mesma planilha/Drive do GS Campo — com busca de CNPJ na Receita."
        action={
          <Link
            href="/clientes"
            className="rounded-xl border border-navy/15 bg-white px-4 py-2.5 text-sm font-medium text-navy hover:bg-paper"
          >
            Voltar
          </Link>
        }
      />
      <ClientCreateForm />
    </div>
  );
}
