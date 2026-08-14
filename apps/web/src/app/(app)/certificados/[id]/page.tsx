import { notFound } from "next/navigation";
import { formatCnpj, formatWorkOrderNumber } from "@gs/shared";
import { PageHeader } from "@/components/ui";
import { getCertificate } from "@/lib/demo/queries";

export default async function CertificadoDetailPage({
  params,
}: {
  params: Promise<{ id: string }>;
}) {
  const { id } = await params;
  const certificate = getCertificate(id);
  if (!certificate) notFound();

  return (
    <div>
      <PageHeader
        title={`Certificado ${certificate.number}`}
        description={
          certificate.source === "field"
            ? "Recebido do app de campo — planilha Excel anexada pelo técnico."
            : "Prévia do documento que acompanha a planilha CERTIFICADO TESTE."
        }
        action={
          certificate.fileBase64 ? (
            <a
              href={`/api/campo/certificados/${certificate.id}/pdf`}
              target="_blank"
              rel="noreferrer"
              className="inline-flex items-center justify-center rounded-[2px] bg-brass px-3.5 py-2 text-sm font-semibold tracking-wide text-black hover:bg-brass-2"
            >
              Baixar anexo
            </a>
          ) : undefined
        }
      />
      <article className="mx-auto max-w-3xl border border-line bg-white p-8 shadow-[0_0_0_1px_rgba(0,0,0,0.02)]">
        <header className="border-b border-navy pb-4">
          <div className="text-xs uppercase tracking-[0.2em] text-brass">
            GS Soluções Técnicas
          </div>
          <h2 className="mt-2 font-serif text-2xl text-navy">
            Certificado de calibração
          </h2>
          <p className="mt-1 text-sm text-muted">
            Certificado nº {certificate.number} · Serviço de calibração volumétrica
          </p>
        </header>

        <section className="mt-6 grid gap-4 text-sm sm:grid-cols-2">
          <div>
            <h3 className="mb-2 text-xs font-medium uppercase tracking-wide text-muted">
              Dados do cliente
            </h3>
            <p>
              {certificate.client?.legalName}
              <br />
              CNPJ {certificate.client ? formatCnpj(certificate.client.cnpj) : "—"}
              <br />
              Base {certificate.client?.alias}
            </p>
          </div>
          <div>
            <h3 className="mb-2 text-xs font-medium uppercase tracking-wide text-muted">
              Serviço
            </h3>
            <p>
              OS{" "}
              {certificate.workOrder
                ? formatWorkOrderNumber(
                    certificate.workOrder.number,
                    certificate.workOrder.year,
                  )
                : "—"}
              <br />
              Emissão{" "}
              {new Date(`${certificate.issuedAt}T00:00:00`).toLocaleDateString("pt-BR")}
              <br />
              Próxima calibração{" "}
              {new Date(`${certificate.nextDue}T00:00:00`).toLocaleDateString("pt-BR")}
            </p>
          </div>
        </section>

        <section className="mt-6 text-sm">
          <h3 className="mb-2 text-xs font-medium uppercase tracking-wide text-muted">
            Instrumento calibrado
          </h3>
          <p>
            {certificate.instrument}
            <br />
            Tag {certificate.tag} · Princípio {certificate.principle}
          </p>
        </section>

        <section className="mt-6 text-sm">
          <h3 className="mb-2 text-xs font-medium uppercase tracking-wide text-muted">
            Padrão envolvido
          </h3>
          <p>{certificate.standard}</p>
          <p className="mt-2 text-muted">
            Método: comparação direta · Procedimento PQ-30.005
          </p>
        </section>

        <section className="mt-6">
          <h3 className="mb-2 text-xs font-medium uppercase tracking-wide text-muted">
            Resultados (prévia)
          </h3>
          <table className="w-full text-left text-xs">
            <thead className="border-b border-line text-muted">
              <tr>
                <th className="py-2 font-medium">Vazão (L/min)</th>
                <th className="font-medium">Erro (%)</th>
                <th className="font-medium">Repetib. (%)</th>
                <th className="font-medium">U (k=2)</th>
              </tr>
            </thead>
            <tbody>
              {[
                ["400", "0,43", "0,08", "0,21"],
                ["1100", "0,86", "0,11", "0,24"],
                ["1700", "0,47", "0,07", "0,19"],
                ["2250", "0,16", "0,06", "0,18"],
              ].map((row) => (
                <tr key={row[0]} className="border-b border-line">
                  {row.map((cell) => (
                    <td key={cell} className="py-2">
                      {cell}
                    </td>
                  ))}
                </tr>
              ))}
            </tbody>
          </table>
        </section>

        <footer className="mt-8 grid gap-6 text-sm sm:grid-cols-2">
          <div>
            <div className="h-12 border-b border-ink/40 font-serif italic text-navy">
              {certificate.signer}
            </div>
            <div className="mt-1 text-xs text-muted">Signatário autorizado</div>
          </div>
          <div>
            <div className="h-12 border-b border-ink/40 font-serif italic text-navy">
              {certificate.client?.manager.name}
            </div>
            <div className="mt-1 text-xs text-muted">Responsável da base</div>
          </div>
        </footer>
      </article>
    </div>
  );
}
