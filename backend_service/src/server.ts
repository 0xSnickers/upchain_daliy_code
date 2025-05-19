import express from 'express'
import cors from 'cors'
import dotenv from 'dotenv'
import router from './routes'

dotenv.config()
const app = express()
app.use(cors())
app.use(express.json())

app.use('/api', router)

const PORT = process.env.PORT || 9000
app.listen(PORT, () => {
  console.log(`🚀 🚀 🚀  Server running at http://localhost:${PORT}`)
})
