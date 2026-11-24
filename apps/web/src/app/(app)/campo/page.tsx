import Link from "next/link";
import { PageHeader, Panel } from "@/components/ui";

const CAMPO_URL =
  process.env.NEXT_PUBLIC_CAMPO_URL?.trim() || "https://gs-campo.netlify.app";

/** Versão publicada no monorepo (apps/mobile). O PWA precisa bater com isto. */
const CAMPO_EXPECTED_VERSION = "1.2.100";

export default function CampoPage() {
  return (
    <div>
      <PageHeader
        eyebrow="Campo"
        title="App do técnico"
        description={`O GS Campo continua no navegador/PWA (versão esperada ${CAMPO_EXPECTED_VERSION}). Se a tela de boot mostrar outra, force atualizar / limpar cache.`}
      />
      <div className="grid gap-4 lg:grid-cols-2">
        <Panel>
          <h2 className="font-serif text-xl text-navy">Abrir GS Campo</h2>
          <p className="mt-2 text-sm leading-7 text-navy/65">
            RDO, fotos, assinatura e envio no aparelho do técnico — sem misturar
            com o fluxo de escritório. Build atual do repositório:{" "}
            <strong className="font-medium text-navy">
              {CAMPO_EXPECTED_VERSION}+293
            </strong>
            .
          </p>
          <a
            href={CAMPO_URL}
            target="_blank"
            rel="noreferrer"
            className="mt-5 inline-flex rounded-xl bg-brass px-5 py-3 text-sm font-semibold text-navy hover:bg-brass-2"
          >
            Abrir gs-campo.netlify.app
          </a>
        </Panel>
        <Panel>
          <h2 className="font-serif text-xl text-navy">No escritório</h2>
          <p className="mt-2 text-sm leading-7 text-navy/65">
            Use o menu para OS, clientes, calibração, Drive e equipe — tudo na
            mesma planilha do app.
          </p>
          <Link
            href="/"
            className="mt-5 inline-flex rounded-xl border border-navy/15 px-5 py-3 text-sm font-semibold text-navy hover:bg-paper"
          >
            Voltar à área de trabalho
          </Link>
        </Panel>
      </div>
    </div>
  );
}
