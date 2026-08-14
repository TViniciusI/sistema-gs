import { redirect } from "next/navigation";
import { ROLE_LABELS } from "@gs/shared";
import { AppShell } from "@/components/app-shell";
import { getProfile } from "@/lib/auth";

export default async function AppLayout({
  children,
}: {
  children: React.ReactNode;
}) {
  const profile = await getProfile();
  if (!profile) {
    redirect("/login");
  }

  return (
    <AppShell name={profile.full_name} role={ROLE_LABELS[profile.role]}>
      {children}
    </AppShell>
  );
}
