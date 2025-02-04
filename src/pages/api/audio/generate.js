import { generateAudio } from '../../../utils/tts'
import { authenticate } from '../../../middleware/auth'

export default authenticate(async (req, res) => {
  if (req.method !== 'POST') return res.status(405).end()

  const { text } = req.body

  try {
    // 验证用户权限
    if (req.user.plan !== 'PRO') {
      return res.status(403).json({ error: '需要专业版订阅' })
    }

    const audioData = await generateAudio(text)
    res.setHeader('Content-Type', 'audio/mpeg')
    res.send(audioData)
  } catch (error) {
    res.status(500).json({ error: error.message })
  }
})
