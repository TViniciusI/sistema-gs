import {
  DEFAULT_TECHNICIAN_CARGO,
  formatRdoDate,
  formatRdoSignedAt,
  GS_COMPANY_CNPJ,
  GS_COMPANY_NAME,
  personFirstKey,
  splitTeamNames,
  teamWithLead,
  type OsRdoLite,
  type OsRdoMeta,
} from "@/lib/campo-data";

function Field({ label, value }: { label: string; value?: string }) {
  return (
    <p className="mb-1 text-[9.5pt] leading-snug text-black">
      <span className="font-bold">{label} </span>
      <span>{(value || "").trim()}</span>
    </p>
  );
}

function SectionBar({ title }: { title: string }) {
  return (
    <div className="rdo-section-bar px-2 py-1 text-center text-[10.5pt] font-bold text-black">
      {title}
    </div>
  );
}

function ElectronicStamp({
  name,
  cargo,
  signedAt,
}: {
  name: string;
  cargo: string;
  signedAt: string;
}) {
  const who = name.trim() || "Nome do funcionário";
  return (
    <div className="space-y-0.5 text-[9pt] leading-snug text-black">
      <p className="font-bold">Assinado eletronicamente por:</p>
      <p className="text-[11pt] font-bold">{who}</p>
      {cargo.trim() ? <p>Cargo: {cargo.trim()}</p> : null}
      <p>Data: {signedAt}</p>
      <p>
        {GS_COMPANY_NAME} CNPJ:
        <br />
        {GS_COMPANY_CNPJ}
      </p>
    </div>
  );
}

function OpenSignBlock({
  title,
  name,
  cargo,
}: {
  title: string;
  name: string;
  cargo: string;
}) {
  return (
    <div className="text-[9pt] text-black">
      <p className="font-bold">{title}</p>
      <div className="mt-7 border-b border-black" />
      <p className="mt-1.5 text-[10pt] font-bold">
        {name.trim() || "Nome:"}
      </p>
      {cargo.trim() ? <p className="mt-0.5">Cargo: {cargo.trim()}</p> : null}
    </div>
  );
}

function resolveCargo(
  name: string,
  cargos: Record<string, string>,
  fallback: string,
) {
  if (name === "-") return "-";
  const stored = cargos[personFirstKey(name)]?.trim() || "";
  if (stored) {
    const folded = stored
      .normalize("NFD")
      .replace(/[\u0300-\u036f]/g, "")
      .toLowerCase();
    if (
      folded === "tecnico" ||
      folded === "tecnico e administrativo" ||
      stored.includes(" · ") ||
      /^\d{1,2}:\d{2}$/.test(stored)
    ) {
      return fallback || DEFAULT_TECHNICIAN_CARGO;
    }
    return stored;
  }
  return fallback || DEFAULT_TECHNICIAN_CARGO;
}

function resolveFuncao(
  name: string,
  leadKey: string,
  funcoes: Record<string, string>,
) {
  if (name === "-") return "-";
  const stored = funcoes[personFirstKey(name)]?.trim() || "";
  if (stored) return stored;
  if (leadKey && personFirstKey(name) === leadKey) return "Responsável técnico";
  return "Suporte Técnico";
}

export function RdoServiceReport({
  osNumber,
  technicianName,
  meta,
  entry,
}: {
  osNumber: string;
  technicianName: string;
  meta: OsRdoMeta;
  entry: OsRdoLite;
}) {
  const lead =
    entry.responsibleName.trim() ||
    splitTeamNames(technicianName)[0] ||
    "";
  const names = teamWithLead(splitTeamNames(technicianName), lead);
  const fallbackCargo = meta.technicianCargo || DEFAULT_TECHNICIAN_CARGO;
  const leadCargo = resolveCargo(names[0] || "-", meta.technicianCargos, fallbackCargo);
  const leadKey = personFirstKey(names[0] || "");
  const baseName = meta.baseName.trim();
  const baseCargo = meta.baseCargo.trim();
  const day = formatRdoDate(entry.date);
  const techSignedAt = formatRdoSignedAt(entry.signedAt, entry.date);
  const clientSignedAt = formatRdoSignedAt(entry.clientSignedAt);
  const withTechSignature = entry.signed && Boolean(lead.trim());
  const withClientSignature =
    Boolean(entry.clientSignedName.trim() || entry.clientSignedAt) &&
    Boolean(baseName);

  const teamRows = [...names];
  while (teamRows.length < 4) teamRows.push("-");

  return (
    <article className="rdo-doc mx-auto max-w-[210mm] bg-white text-black shadow-[0_12px_32px_rgba(12,31,51,0.08)] print:max-w-none print:shadow-none">
      <img
        src="/rdo/header.png"
        alt="GS Soluções"
        className="block w-full"
      />

      <div className="border border-black border-b-0">
        <div className="px-2 py-2 text-center">
          <h1 className="text-[13pt] font-bold underline">
            RELATÓRIO DE SERVIÇO
          </h1>
        </div>

        <SectionBar title="Dados do Contratante" />
        <div className="space-y-0.5 px-2.5 py-1.5">
          <div className="grid grid-cols-[1.5fr_1fr] gap-2">
            <Field label="Contratante:" value={meta.client} />
            <Field label="CNPJ:" value={meta.cnpj} />
          </div>
          <Field label="Endereço:" value={meta.site} />
          <div className="grid grid-cols-[1.5fr_1fr] gap-2">
            <Field label="Responsável:" value={baseName} />
            <Field label="Cargo:" value={baseCargo} />
          </div>
          <div className="grid grid-cols-[1.5fr_1fr] gap-2">
            <Field label="Telefone:" value={meta.basePhone} />
            <Field label="E-mail:" value={meta.baseEmail} />
          </div>
        </div>

        <SectionBar title="Informações do Serviço" />
        <div className="grid grid-cols-[1fr_2fr_2fr] gap-2 px-2.5 py-1.5">
          <Field label="OS Nº:" value={osNumber} />
          <Field label="Serviço Contratado:" value={meta.service} />
          <Field label="Tipo de Sistema:" value={meta.systemType} />
        </div>

        <SectionBar title="Equipe Técnica" />
        <div className="px-2.5 py-1">
          {teamRows.map((name, index) => (
            <div
              key={`${name}-${index}`}
              className="grid grid-cols-[3fr_4fr_3fr] gap-2 py-0.5 text-[9pt]"
            >
              <p>
                <span className="font-bold">Nome: </span>
                {name}
              </p>
              <p>
                <span className="font-bold">Cargo: </span>
                {resolveCargo(name, meta.technicianCargos, fallbackCargo)}
              </p>
              <p>
                <span className="font-bold">Função: </span>
                {resolveFuncao(name, leadKey, meta.technicianFuncoes)}
              </p>
            </div>
          ))}
        </div>

        <SectionBar title="Registro do Dia" />
        <table className="w-full border-collapse text-center text-[8pt]">
          <thead>
            <tr className="border-t border-black">
              {[
                "Data do Serviço",
                "Entrada",
                "Início do Almoço",
                "Retorno do Almoço",
                "Saída",
              ].map((h) => (
                <th
                  key={h}
                  className="border-r border-black px-1 py-1.5 font-bold last:border-r-0"
                >
                  {h}
                </th>
              ))}
            </tr>
          </thead>
          <tbody>
            <tr className="border-t border-black">
              {[
                day,
                entry.clockIn,
                entry.lunchStart,
                entry.lunchEnd,
                entry.clockOut,
              ].map((v, i) => (
                <td
                  key={i}
                  className="border-r border-black px-1 py-1.5 last:border-r-0"
                >
                  {v || ""}
                </td>
              ))}
            </tr>
          </tbody>
        </table>
      </div>

      <div className="border-x border-black">
        <SectionBar title="Descrição Detalhada do Serviço" />
      </div>
      <div className="min-h-[88px] border-x border-black px-2.5 py-1.5 text-[9pt] leading-relaxed whitespace-pre-wrap">
        {entry.description}
      </div>

      <div className="border-x border-black">
        <SectionBar title="Informações Adicionais do Serviço" />
      </div>
      <div className="min-h-[36px] border-x border-black px-2.5 py-1.5 text-[9pt] leading-relaxed whitespace-pre-wrap">
        {entry.notes}
      </div>

      <div className="border border-t-0 border-black px-4 py-4">
        <div className="grid grid-cols-2 gap-7">
          {withTechSignature ? (
            <ElectronicStamp
              name={lead}
              cargo={leadCargo}
              signedAt={techSignedAt}
            />
          ) : (
            <OpenSignBlock
              title="Responsável técnico"
              name={lead}
              cargo={leadCargo}
            />
          )}
          {withClientSignature ? (
            <ElectronicStamp
              name={entry.clientSignedName || baseName}
              cargo={baseCargo}
              signedAt={clientSignedAt}
            />
          ) : (
            <OpenSignBlock
              title="Responsável da base"
              name={baseName}
              cargo={baseCargo}
            />
          )}
        </div>
      </div>

      <img
        src="/rdo/footer.png"
        alt=""
        className="mt-1 block w-full"
      />
    </article>
  );
}
