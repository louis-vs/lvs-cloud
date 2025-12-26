class DashboardController < ApplicationController
  def index
    @recent_imports = Import.order(created_at: :desc).limit(5)
    @recent_statements = Statement.order(created_at: :desc).limit(5)
    @stats = {
      total_royalties: Royalty.count,
      assigned_royalties: Royalty.where.not(statement_id: nil).count,
      total_writers: Writer.count,
      total_works: Work.count,
      pending_statements: Statement.where(status: [ :pending, :processing ]).count,
      invoiced_statements: Statement.where(invoiced: true).count
    }
  end
end
