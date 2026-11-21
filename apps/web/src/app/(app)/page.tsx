import Link from "next/link";
import { Icons } from "@/components/icons";
import { HubCard, PageHeader, StatusPill } from "@/components/ui";
import { getProfile } from "@/lib/auth";
import {
  listCampoCalibrations,
  listCampoClients,
  listCampoOrders,
  listCampoStaffDocs,
  listCampoStandards,
  listCampoUsers,
} from "@/lib/campo-data";
import {
  campoOsStatusLabel,
  campoOsStatusTone,
} from "@/lib/campo-data/labels";

export const dynamic = "force-dynamic";

export default async function DashboardPage() {
  const profile = await getProfile();
  const [orders, clients, users, calibrations, standards, docs] =
    await Promise.all([
      listCampoOrders(),
      listCampoClients(),
      listCampoUsers(),
      listCampoCalibrations(),
      listCampoStandards(),
      listCampoStaffDocs(),
    ]);

  const open = orders.filter((os) => {
    const s = os.status.toLowerCase().replace(/\s+/g, "");
    return s !== "encerrada";
  });
  const pendingUsers = users.filter((u) => u.status === "pendente");
  const dueStandards = standards.filter((s) => {
    if (!s.validity) return false;
    const t = Date.parse(s.validity);
    if (!Number.isFinite(t)) return false;
    return t - Date.now() < 1000 * 60 * 60 * 24 * 60;
  });
  const recent = orders.slice(0, 6);
  const firstName = (profile?.full_name || "GS").split(/\s+/)[0];

  return (
    <div>
      <section className="relative overflow-hidden rounded-3xl border border-navy/10 bg-navy px-6 py-7 text-paper shadow-[0_20px_50px_rgba(12,31,51,0.18)] md:px-8">
        <div
          aria-hidden
          className="pointer-events-none absolute -right-16 top-1/2 size-[280px] -translate-y-1/2 rounded-full border border-brass/25"
        />
        <div
          aria-hidden
          className="pointer-events-none absolute -right-4 top-1/2 size-[160px] -translate-y-1/2 rounded-full border border-brass/35"
        />
        <p className="relative text-[11px] font-semibold uppercase tracking-[0.32em] text-brass">
          GS Soluções Técnicas
        </p>
        <h1 className="relative mt-3 max-w-xl font-serif text-3xl leading-tight md:text-4xl">
          Olá, {firstName}
        </h1>
        <p className="relative mt-3 max-w-2xl text-[15px] leading-7 text-paper/70">
          Escritório completo com tudo o que o GS Campo faz — OS, cadastros,
          calibração, arquivos e acessos — na mesma base, em layout profissional.
        </p>
        <div className="relative mt-6 flex flex-wrap gap-3 text-sm">
          <span className="rounded-full bg-white/10 px-3 py-1.5 text-paper/80">
            {open.length} OS em aberto
          </span>
          <span className="rounded-full bg-white/10 px-3 py-1.5 text-paper/80">
            {clients.length} clientes
          </span>
          <span className="rounded-full bg-white/10 px-3 py-1.5 text-paper/80">
            {calibrations.length} calibrações
          </span>
        </div>
      </section>

      <div className="mt-8">
        <PageHeader
          eyebrow="Área de trabalho"
          title="Tudo do app, no escritório"
          description="Os mesmos módulos do GS Campo, organizados para tela grande."
        />
      </div>

      <div className="grid gap-4 sm:grid-cols-2 xl:grid-cols-3">
        <HubCard
          href="/agenda"
          title="Agenda da semana"
          description="Serviços programados a partir das OS da planilha."
          icon={Icons.calendar}
          meta={`${open.length} abertas`}
        />
        <HubCard
          href="/equipe"
          title="Funcionários"
          description="Acessos, papéis e aprovação — igual à gestão do app."
          icon={Icons.users}
          meta={
            pendingUsers.length > 0
              ? `${pendingUsers.length} pendente(s)`
              : `${users.length} usuários`
          }
        />
        <HubCard
          href="/clientes"
          title="Clientes e sistemas"
          description="Cadastro compartilhado, instrumentos e exclusão na fonte da verdade."
          icon={Icons.building}
          meta={`${clients.length}`}
        />
        <HubCard
          href="/os"
          title="Gerar / acompanhar OS"
          description="Lista completa de ordens, status, técnicos e RDOs."
          icon={Icons.clipboard}
          meta={`${orders.length} OS`}
        />
        <HubCard
          href="/calibracao"
          title="Calibração"
          description="Trabalhos de calibração gravados no Campo."
          icon={Icons.wrench}
          meta={`${calibrations.length}`}
        />
        <HubCard
          href="/certificados"
          title="Certificados"
          description="Emissões e vínculos com equipamentos calibrados."
          icon={Icons.shield}
        />
        <HubCard
          href="/padroes"
          title="Padrões"
          description="Padrões de referência usados nos ensaios."
          icon={Icons.shield}
          meta={`${standards.length}`}
        />
        <HubCard
          href="/fluidos"
          title="Fluidos"
          description="Cadastro de fluidos para calibração."
          icon={Icons.wrench}
        />
        <HubCard
          href="/tabelas"
          title="Tabelas 20 °C"
          description="Conversões e correções — mesmo módulo do app."
          icon={Icons.table}
        />
        <HubCard
          href="/documentos"
          title="Documentos RH"
          description="Holerites e anexos da equipe no Drive."
          icon={Icons.users}
          meta={`${docs.length}`}
        />
        <HubCard
          href="/arquivos"
          title="Arquivos / Drive"
          description="Pastas das OS: RDO, fotos, anexos e certificados."
          icon={Icons.clipboard}
        />
        <HubCard
          href="/configuracoes"
          title="Configurações"
          description="Sessão, permissões e status do Google Drive."
          icon={Icons.settings}
        />
        <HubCard
          href="/vencimentos"
          title="Vencimentos"
          description="Padrões próximos do vencimento."
          icon={Icons.clock}
          meta={`${dueStandards.length} a olhar`}
        />
        <HubCard
          href="/campo"
          title="App do técnico"
          description="Atalho para o GS Campo no navegador."
          icon={Icons.phone}
        />
      </div>

      <section className="mt-10">
        <div className="mb-3 flex items-end justify-between gap-3">
          <h2 className="font-serif text-2xl text-navy">Últimas OS</h2>
          <Link href="/os" className="text-sm font-medium text-navy/60 hover:text-navy">
            Ver todas
          </Link>
        </div>
        <div className="divide-y divide-navy/8 overflow-hidden rounded-2xl border border-navy/10 bg-white shadow-[0_8px_24px_rgba(12,31,51,0.04)]">
          {recent.length === 0 ? (
            <p className="px-5 py-8 text-sm text-muted">
              Nenhuma OS carregada da planilha.
            </p>
          ) : (
            recent.map((os) => (
              <Link
                key={os.id}
                href={`/os/${os.id}`}
                className="flex items-center justify-between px-5 py-4 transition hover:bg-paper"
              >
                <div>
                  <div className="font-semibold tracking-wide text-navy">
                    GS {os.number}
                  </div>
                  <div className="mt-0.5 text-sm text-muted">
                    {os.clientName || "—"} · {os.technicianName || "sem técnico"}
                  </div>
                </div>
                <StatusPill
                  label={campoOsStatusLabel(os.status)}
                  tone={campoOsStatusTone(os.status)}
                />
              </Link>
            ))
          )}
        </div>
      </section>
    </div>
  );
}
