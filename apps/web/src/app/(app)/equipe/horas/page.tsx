import { redirect } from "next/navigation";

/** Horas de campo vive como subaba de Funcionários. */
export default async function EquipeHorasRedirect({
  searchParams,
}: {
  searchParams: Promise<{ tech?: string; month?: string }>;
}) {
  const params = await searchParams;
  const qs = new URLSearchParams({ tab: "horas" });
  if (params.tech) qs.set("tech", params.tech);
  if (params.month) qs.set("month", params.month);
  redirect(`/equipe?${qs.toString()}`);
}
