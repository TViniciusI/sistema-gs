export type DashboardOrder = {
  id: string;
  number: string;
  status: string;
  clientName: string;
  technicianName: string;
  startsAt: string;
  updatedAt: string;
};

export type StatusSlice = {
  key: string;
  label: string;
  count: number;
  color: string;
};

export type WeekBucket = {
  label: string;
  key: string;
  count: number;
};

export type TechLoad = {
  name: string;
  count: number;
};
