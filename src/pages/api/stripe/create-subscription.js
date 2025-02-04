import { createSubscriptionSession } from '../../../utils/stripe'
import prisma from '../../../utils/prisma'
import { authenticate } from '../../../middleware/auth'

export default authenticate(async (req, res) => {
  if (req.method !== 'POST') return res.status(405).end()

  try {
    const session = await createSubscriptionSession(
      req.user.id,
      process.env.STRIPE_PRO_PLAN_ID
    )

    await prisma.user.update({
      where: { id: req.user.id },
      data: { stripeId: session.customer }
    })

    res.status(200).json({ sessionId: session.id })
  } catch (error) {
    res.status(500).json({ error: error.message })
  }
})
