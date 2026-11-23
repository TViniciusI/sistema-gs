type BrandLogoProps = {
  className?: string;
  priority?: boolean;
  /**
   * `onDark` — ouro vetorial do app (sidebar / navy).
   * `onLight` — preto vetorial (card branco).
   * `mark` — só o monograma dourado.
   */
  variant?: "onDark" | "onLight" | "mark";
};

/** Logo GS Campo — vetores do app, sem placa nem halo branco. */
export function BrandLogo({
  className = "h-auto w-[200px]",
  priority = false,
  variant = "onDark",
}: BrandLogoProps) {
  if (variant === "mark") {
    return (
      // eslint-disable-next-line @next/next/no-img-element
      <img
        src="/logo-mark.png"
        alt="GS Soluções Técnicas"
        width={415}
        height={346}
        decoding="async"
        {...(priority ? { fetchPriority: "high" as const } : {})}
        className={`bg-transparent object-contain ${className}`}
      />
    );
  }

  const src = variant === "onLight" ? "/logo-black.svg" : "/logo-gold.svg";

  return (
    // eslint-disable-next-line @next/next/no-img-element
    <img
      src={src}
      alt="GS Soluções Técnicas"
      width={451}
      height={424}
      decoding="async"
      {...(priority ? { fetchPriority: "high" as const } : {})}
      className={`bg-transparent object-contain ${className}`}
    />
  );
}
