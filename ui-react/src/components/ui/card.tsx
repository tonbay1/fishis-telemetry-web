import * as React from 'react'
import { clsx } from 'clsx'

export const Card = ({ className, ...props }: React.HTMLAttributes<HTMLDivElement>) => (
  <div className={clsx('bg-card text-card-foreground border rounded-xl', className)} {...props} />
)
export const CardContent = ({ className, ...props }: React.HTMLAttributes<HTMLDivElement>) => (
  <div className={clsx('p-6 pt-0', className)} {...props} />
)
export default Card
