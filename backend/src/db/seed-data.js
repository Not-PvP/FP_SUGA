// Iloilo City's seven official districts.
// Coordinates are approximate district centers, used for the weather lookup.
export const AREAS = [
  { name: 'Arevalo', city: 'Iloilo City', latitude: 10.6880, longitude: 122.5170 },
  { name: 'City Proper', city: 'Iloilo City', latitude: 10.6969, longitude: 122.5644 },
  { name: 'Jaro', city: 'Iloilo City', latitude: 10.7240, longitude: 122.5580 },
  { name: 'La Paz', city: 'Iloilo City', latitude: 10.7090, longitude: 122.5700 },
  { name: 'Lapuz', city: 'Iloilo City', latitude: 10.6990, longitude: 122.5850 },
  { name: 'Mandurriao', city: 'Iloilo City', latitude: 10.7190, longitude: 122.5390 },
  { name: 'Molo', city: 'Iloilo City', latitude: 10.6950, longitude: 122.5440 },
];

// DEVELOPMENT SAMPLE DATA: placeholder feeder names, not MORE Power's real feeders.
// Replace these with verified feeder names from official advisories.
export const FEEDERS = [
  { area: 'Arevalo', name: 'Arevalo Feeder 1' },
  { area: 'City Proper', name: 'City Proper Feeder 1' },
  { area: 'City Proper', name: 'City Proper Feeder 2' },
  { area: 'Jaro', name: 'Jaro Feeder 1' },
  { area: 'Jaro', name: 'Jaro Feeder 2' },
  { area: 'La Paz', name: 'La Paz Feeder 1' },
  { area: 'La Paz', name: 'La Paz Feeder 2' },
  { area: 'Lapuz', name: 'Lapuz Feeder 1' },
  { area: 'Mandurriao', name: 'Mandurriao Feeder 1' },
  { area: 'Molo', name: 'Molo Feeder 1' },
];

// DEVELOPMENT SAMPLE DATA: example advisories for testing the app.
export const INTERRUPTIONS = [
  {
    title: 'Jaro Power Interruption',
    description: 'Power will be interrupted in parts of Jaro District for scheduled line maintenance.',
    date: '2026-10-12',
    startTime: '09:00',
    endTime: '14:00',
    reason: 'Scheduled Maintenance',
    status: 'scheduled',
    estimatedRestoration: '14:00',
    areas: ['Jaro'],
    feeders: ['Jaro Feeder 1', 'Jaro Feeder 2'],
  },
  {
    title: 'La Paz Power Interruption',
    description: 'Power will be interrupted in parts of La Paz for pole replacement.',
    date: '2026-10-12',
    startTime: '17:00',
    endTime: '20:00',
    reason: 'Pole Replacement',
    status: 'scheduled',
    estimatedRestoration: '20:00',
    areas: ['La Paz'],
    feeders: ['La Paz Feeder 1', 'La Paz Feeder 2'],
  },
  {
    title: 'Molo Power Interruption',
    description: 'Power will be interrupted in parts of Molo for line upgrading.',
    date: '2026-10-14',
    startTime: '08:00',
    endTime: '12:00',
    reason: 'Line Upgrading',
    status: 'scheduled',
    estimatedRestoration: '12:00',
    areas: ['Molo'],
    feeders: ['Molo Feeder 1'],
  },
];
