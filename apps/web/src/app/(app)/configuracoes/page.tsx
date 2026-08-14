import { PageHeader, Panel } from "@/components/ui";

export default function ConfiguracoesPage() {
  return (
    <div>
      <PageHeader
        title="Configurações"
        description="Preferências da empresa — nesta demonstração o cadastro já está definido."
      />
      <Panel>
        <dl className="space-y-3 text-sm">
          <div>
            <dt className="text-xs uppercase tracking-wide text-muted">Empresa</dt>
            <dd>GS Soluções Técnicas</dd>
          </div>
          <div>
            <dt className="text-xs uppercase tracking-wide text-muted">Unidade</dt>
            <dd>Belém / PA</dd>
          </div>
          <div>
            <dt className="text-xs uppercase tracking-wide text-muted">Perfil</dt>
            <dd>Cleber Guimarães · Administrador</dd>
          </div>
        </dl>
      </Panel>
    </div>
  );
}
