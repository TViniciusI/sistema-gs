import { Button, ErrorText, Field, FormGrid, PageHeader, Panel } from "@/components/ui";
import { createEmployeeRecord } from "../../cadastros/actions";

export default async function NovoEquipePage({
  searchParams,
}: {
  searchParams: Promise<{ error?: string }>;
}) {
  const { error } = await searchParams;

  return (
    <div>
      <PageHeader
        title="Novo integrante"
        description="Nesta demonstração o cadastro fica só nesta sessão do navegador."
      />
      <Panel>
        <form action={createEmployeeRecord} className="space-y-6">
          <ErrorText message={error} />
          <FormGrid>
            <Field label="Nome" name="full_name" required />
            <Field label="Cargo" name="job_title" />
            <Field label="Telefone" name="phone" />
          </FormGrid>
          <label className="flex items-center gap-2 text-sm">
            <input type="checkbox" name="is_technician" defaultChecked className="accent-navy" />
            Atua em campo (técnico)
          </label>
          <Button type="submit">Salvar</Button>
        </form>
      </Panel>
    </div>
  );
}
