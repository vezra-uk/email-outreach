// frontend/src/app/layout.tsx
import './globals.css'
import Header from '../components/header'

export const metadata = {
  title: 'Email Automation System',
  description: 'Cold email automation with AI personalization',
}

export default function RootLayout({
  children,
}: {
  children: React.ReactNode
}) {
  return (
    <html lang="en">
      <body>
        <Header />
        <main>
          {children}
        </main>
      </body>
    </html>
  )
}