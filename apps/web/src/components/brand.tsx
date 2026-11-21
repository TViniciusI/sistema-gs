import Image from "next/image";

type BrandLogoProps = {
  className?: string;
  priority?: boolean;
  /** `full` = GS + SOLUÇÕES TÉCNICAS; `mark` = só o monograma. */
  variant?: "full" | "mark";
};

/** Logo GS Campo sem placa/fundo — mesmo asset transparente do app. */
export function BrandLogo({
  className = "h-auto w-[200px]",
  priority = false,
  variant = "full",
}: BrandLogoProps) {
  const isMark = variant === "mark";

  return (
    <Image
      src={isMark ? "/logo-mark.png" : "/logo-clear.png"}
      alt="GS Soluções Técnicas"
      width={isMark ? 415 : 342}
      height={isMark ? 346 : 325}
      priority={priority}
      className={`bg-transparent object-contain ${className}`}
    />
  );
}
