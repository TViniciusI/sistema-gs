import Link from "next/link";
import { DataTable, PageHeader, Panel } from "@/components/ui";
import {
  getCampoOrder,
  isFieldTechnicianUser,
  listCampoOrders,
  listCampoUsers,
  parseOsRdos,
  type CampoOrder,
} from "@/lib/campo-data";
import {
  formatWorkedHours,
  normalizePersonKey,
  rdoWorkedMinutes,
} from "@/lib/campo-data/work-hours";

export const dynamic = "force-dynamic";

function formatDatePt(raw: string) {
  const d = new Date(raw);
  if (!Number.isNaN(d.getTime())) {
    return d.toLocaleDateString("pt-BR", { timeZone: "America/Sao_Paulo" });
  }
  return raw || "—";
}

function orderMentionsTech(os: CampoOrder, keys: Set<string>) {
  const blob = normalizePersonKey(
    [
      os.technicianName,
      String(os.raw.technicianEmail || ""),
      String(os.raw.technicianEmails || ""),
    ].join(" "),
  );
  return [...keys].some((k) => k && blob.includes(k));
}

export default async function EquipeHorasPage({
  searchParams,
}: {
  searchParams: Promise<{ tech?: string }>;
}) {
  const { tech: techFilter } = await searchParams;
  const [users, orders] = await Promise.all([
    listCampoUsers(),
    listCampoOrders(),
  ]);

  const technicians = users
    .filter((u) => u.active && isFieldTechnicianUser(u))
    .sort((a, b) => a.name.localeCompare(b.name, "pt-BR"));

  const selected =
    technicians.find(
      (u) =>
        normalizePersonKey(u.name) === normalizePersonKey(techFilter || "") ||
        normalizePersonKey(u.email) === normalizePersonKey(techFilter || "") ||
        normalizePersonKey(u.login) === normalizePersonKey(techFilter || ""),
    ) || technicians[0] || null;

  const selectedKeys = selected
    ? new Set(
        [selected.name, selected.email, selected.login]
          .map(normalizePersonKey)
          .filter(Boolean),
      )
    : new Set<string>();

  // listos é leve (sem RDOs). Hidrata getos nas OS do técnico (limite).
  const candidates = selected
    ? orders.filter((os) => orderMentionsTech(os, selectedKeys)).slice(0, 24)
    : [];

  const hydrated = await Promise.all(
    candidates.map(async (os) => {
      if (!os.payloadLight && Array.isArray(os.raw.rdos) && os.raw.rdos.length) {
        return os;
      }
      return (await getCampoOrder(os.id)) || os;
    }),
  );

  type Row = {
    osId: string;
    osNumber: string;
    client: string;
    date: string;
    clockIn: string;
    clockOut: string;
    minutes: number;
    responsible: string;
  };

  const rows: Row[] = [];
  for (const os of hydrated) {
    if (normalizePersonKey(os.status) === "rascunho") continue;
    const teamHit = orderMentionsTech(os, selectedKeys);
    for (const rdo of parseOsRdos(os)) {
      const responsible = normalizePersonKey(rdo.responsibleName);
      const belongs =
        (responsible && selectedKeys.has(responsible)) ||
        (!responsible && teamHit) ||
        teamHit;
      if (!belongs) continue;
      const minutes = rdoWorkedMinutes(rdo);
      if (minutes <= 0 && !rdo.clockIn && !rdo.clockOut) continue;
      rows.push({
        osId: os.id,
        osNumber: os.number,
        client: os.clientName || "—",
        date: rdo.date,
        clockIn: rdo.clockIn || "—",
        clockOut: rdo.clockOut || "—",
        minutes,
        responsible: rdo.responsibleName || os.technicianName || "—",
      });
    }
  }

  rows.sort((a, b) => {
    const da = new Date(a.date).getTime() || 0;
    const db = new Date(b.date).getTime() || 0;
    return db - da;
  });

  const totalMinutes = rows.reduce((sum, r) => sum + r.minutes, 0);

  return (
    <div>
      <PageHeader
        eyebrow="RH"
        title="Horas de campo"
        description="Soma dos RDOs (entrada / almoço / saída) — mesma regra do GS Campo."
        action={
          <Link
            href="/equipe"
            className="rounded-xl border border-navy/15 bg-white px-4 py-2.5 text-sm font-medium text-navy hover:bg-paper"
          >
            Funcionários
          </Link>
        }
      />

      <Panel>
        <p className="text-sm text-navy/70">
          Escolha o técnico. Horas = presença menos almoço (padrão 1h se o dia
          passar de 6h e o RDO não informar almoço). Lê até 24 OS recentes do
          técnico (payload completo).
        </p>
        <div className="mt-4 flex flex-wrap gap-2">
          {technicians.map((user) => {
            const active =
              selected &&
              normalizePersonKey(user.name) ===
                normalizePersonKey(selected.name);
            return (
              <Link
                key={user.email || user.login}
                href={`/equipe/horas?tech=${encodeURIComponent(user.name)}`}
                className={[
                  "rounded-xl px-3 py-2 text-sm font-medium transition",
                  active
                    ? "bg-navy text-paper"
                    : "border border-navy/15 bg-paper text-navy hover:border-brass/40",
                ].join(" ")}
              >
                {user.name}
              </Link>
            );
          })}
          {technicians.length === 0 ? (
            <p className="text-sm text-muted">Nenhum técnico ativo no gate.</p>
          ) : null}
        </div>
      </Panel>

      {selected ? (
        <div className="mt-6">
          <div className="mb-3 flex flex-wrap items-end justify-between gap-3">
            <div>
              <h2 className="font-serif text-xl text-navy">{selected.name}</h2>
              <p className="text-sm text-navy/55">
                {rows.length} RDO(s) · total {formatWorkedHours(totalMinutes)}
              </p>
            </div>
          </div>
          <DataTable
            headers={[
              "Data",
              "OS",
              "Cliente",
              "Entrada",
              "Saída",
              "Horas",
              "Responsável",
            ]}
            empty="Nenhum RDO com ponto para este técnico."
            rows={rows.map((row) => [
              formatDatePt(row.date),
              <Link
                key={`${row.osId}-${row.date}-os`}
                href={`/os/${row.osId}/rdo`}
                className="font-medium text-navy hover:underline"
              >
                GS {row.osNumber}
              </Link>,
              row.client,
              row.clockIn,
              row.clockOut,
              formatWorkedHours(row.minutes),
              row.responsible,
            ])}
          />
        </div>
      ) : null}
    </div>
  );
}
