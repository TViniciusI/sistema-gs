import {
  SERVICE_TYPE_LABELS,
  SERVICE_TYPES,
  SYSTEM_TYPE_LABELS,
  SYSTEM_TYPES,
} from "@gs/shared";
import {
  Button,
  Field,
  FormGrid,
  PageHeader,
  Panel,
  SelectField,
} from "@/components/ui";
import { createWorkOrder } from "../actions";
import { listClients, listLocations, listTechnicians } from "@/lib/demo/queries";

export default function NovaOsPage() {
  const clients = listClients();
  const locations = listLocations();
  const technicians = listTechnicians();

  return (
    <div>
      <PageHeader
        title="Nova ordem de serviço"
        description="Na demonstração a OS entra na sessão local. Em produção o número vem do servidor."
      />
      <Panel>
        <form action={createWorkOrder} className="space-y-6">
          <FormGrid>
            <SelectField
              label="Cliente"
              name="client_id"
              required
              options={clients.map((client) => ({
                value: client.id,
                label: client.legalName,
              }))}
            />
            <SelectField
              label="Local"
              name="location_id"
              options={locations.map((location) => ({
                value: location.id,
                label: `${location.alias} · ${location.client?.legalName ?? ""}`,
              }))}
            />
            <Field label="Nº da OC / pedido" name="purchase_order" />
            <Field
              label="Data do serviço"
              name="scheduled_date"
              type="date"
              defaultValue="2026-08-14"
            />
            <SelectField
              label="Serviço contratado"
              name="service_type"
              required
              defaultValue="calibracao"
              options={SERVICE_TYPES.map((value) => ({
                value,
                label: SERVICE_TYPE_LABELS[value],
              }))}
            />
            <SelectField
              label="Tipo de sistema"
              name="system_type"
              defaultValue="carregamento"
              options={SYSTEM_TYPES.map((value) => ({
                value,
                label: SYSTEM_TYPE_LABELS[value],
              }))}
            />
          </FormGrid>
          <div>
            <div className="mb-2 text-xs font-medium uppercase tracking-wide text-muted">
              Equipe técnica
            </div>
            <div className="space-y-2">
              {technicians.map((tech) => (
                <label key={tech.technicianId} className="flex items-center gap-2 text-sm">
                  <input
                    type="checkbox"
                    name="technician_id"
                    value={tech.technicianId}
                    className="accent-navy"
                  />
                  {tech.name}
                </label>
              ))}
            </div>
            <div className="mt-3 max-w-sm">
              <SelectField
                label="Responsável técnico"
                name="owner_technician_id"
                options={technicians.map((tech) => ({
                  value: tech.technicianId ?? "",
                  label: tech.name,
                }))}
              />
            </div>
          </div>
          <Field label="Observações" name="notes" />
          <Button type="submit">Criar OS</Button>
        </form>
      </Panel>
    </div>
  );
}
