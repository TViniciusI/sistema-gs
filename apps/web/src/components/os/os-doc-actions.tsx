import Link from "next/link";

type Action = {
  href: string;
  label: string;
  tone?: "primary" | "ghost";
  external?: boolean;
  disabled?: boolean;
  hint?: string;
};

export function OsDocActions({
  osId,
  hasSlots,
  hasRdos,
  driveUrl,
  campoUrl,
  showHubLink = true,
}: {
  osId: string;
  hasSlots: boolean;
  hasRdos: boolean;
  driveUrl?: string;
  campoUrl: string;
  showHubLink?: boolean;
}) {
  const actions: Action[] = [];

  if (showHubLink) {
    actions.push({
      href: `/os/${osId}/documentos`,
      label: "Abrir documentos da OS",
      tone: "primary",
    });
  }

  actions.push(
    {
      href: `/os/${osId}/certificados`,
      label: "Ver certificados / PDF Drive",
      tone: "primary",
      disabled: !hasSlots,
      hint: hasSlots ? undefined : "Sem slots de calibração nesta OS",
    },
    {
      href: `/os/${osId}/livro`,
      label: "Ver livro de certificados",
      tone: "ghost",
      disabled: !hasSlots,
    },
    {
      href: `/os/${osId}/rdo`,
      label: "Ver / imprimir RDO",
      tone: "ghost",
      disabled: !hasRdos,
      hint: hasRdos ? undefined : "Ainda sem RDO nesta OS",
    },
  );

  if (driveUrl) {
    actions.push({
      href: driveUrl,
      label: "Abrir pasta no Google Drive",
      tone: "primary",
      external: true,
    });
  }

  actions.push({
    href: campoUrl,
    label: "Abrir no GS Campo",
    tone: "ghost",
    external: true,
  });

  return (
    <div className="space-y-2">
      {actions.map((action) => {
        const className = [
          "flex w-full items-center justify-between rounded-2xl px-4 py-3.5 text-left text-sm font-semibold transition",
          action.disabled
            ? "cursor-not-allowed border border-navy/10 bg-paper/70 text-navy/35"
            : action.tone === "primary"
              ? "bg-navy text-paper hover:bg-navy-2"
              : "border border-navy/15 bg-paper text-navy hover:border-brass/45",
        ].join(" ");

        if (action.disabled) {
          return (
            <div key={action.label} className={className} title={action.hint}>
              <span>{action.label}</span>
              {action.hint ? (
                <span className="text-[11px] font-medium normal-case tracking-normal text-navy/35">
                  {action.hint}
                </span>
              ) : null}
            </div>
          );
        }

        if (action.external) {
          return (
            <a
              key={action.label}
              href={action.href}
              target="_blank"
              rel="noreferrer"
              className={className}
            >
              <span>{action.label}</span>
              <span aria-hidden>↗</span>
            </a>
          );
        }

        return (
          <Link key={action.label} href={action.href} className={className}>
            <span>{action.label}</span>
            <span aria-hidden>→</span>
          </Link>
        );
      })}
    </div>
  );
}
