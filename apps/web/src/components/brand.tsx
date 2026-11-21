import Image from "next/image";

/** Logo GS Campo (dourado, fundo transparente) — mesmo asset do app. */
export function BrandLogo({
  className = "h-auto w-[200px]",
  priority = false,
}: {
  className?: string;
  priority?: boolean;
}) {
  return (
    <Image
      src="/logo-gold.svg"
      alt="GS Soluções Técnicas"
      width={451}
      height={424}
      priority={priority}
      className={`bg-transparent object-contain ${className}`}
    />
  );
}
