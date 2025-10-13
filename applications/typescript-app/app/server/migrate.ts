#!/usr/bin/env bun
import { readdir, readFile } from 'fs/promises'
import { join } from 'path'
import pool from './db'

async function runMigrations() {
  console.log('🚀 Running database migrations...')

  try {
    // Create migrations tracking table
    await pool.query(`
      CREATE TABLE IF NOT EXISTS migrations (
        id SERIAL PRIMARY KEY,
        filename VARCHAR(255) NOT NULL UNIQUE,
        executed_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
      )
    `)

    // Get list of migration files
    const migrationsDir = join(process.cwd(), 'migrations')
    const files = await readdir(migrationsDir)
    const sqlFiles = files.filter((f) => f.endsWith('.sql')).sort()

    for (const file of sqlFiles) {
      // Check if migration was already executed
      const result = await pool.query(
        'SELECT id FROM migrations WHERE filename = $1',
        [file]
      )

      if (result.rows.length > 0) {
        console.log(`⏭️  Skipping ${file} (already executed)`)
        continue
      }

      // Read and execute migration
      console.log(`▶️  Executing ${file}...`)
      const sql = await readFile(join(migrationsDir, file), 'utf-8')
      await pool.query(sql)

      // Record migration
      await pool.query('INSERT INTO migrations (filename) VALUES ($1)', [file])
      console.log(`✅ ${file} executed successfully`)
    }

    console.log('🎉 All migrations completed')
  } catch (error) {
    console.error('❌ Migration failed:', error)
    throw error
  } finally {
    await pool.end()
  }
}

// Run migrations
runMigrations().catch((error) => {
  console.error(error)
  process.exit(1)
})
