import Image from "next/image";

export function BrandLogo({
  className = "h-auto w-[200px]",
  priority = false,
}: {
  className?: string;
  priority?: boolean;
}) {
  return (
    <Image
      src="/logo.png"
      alt="GS Soluções Técnicas"
      width={133}
      height={116}
      priority={priority}
      className={className}
    />
  );
}
