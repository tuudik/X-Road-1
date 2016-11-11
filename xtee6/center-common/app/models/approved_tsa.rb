class ApprovedTsa < ActiveRecord::Base
  include Validators

  validates_with MaxlengthValidator
  validates :url, :presence => true, :url => true
  validates :cert, :presence => true
  validates_uniqueness_of :cert,
      :message => I18n.t("errors.tsp.cert_and_url_exists"),
      :scope => :url

  before_save do |tsp|
    cert_obj = CommonUi::CertUtils.cert_object(tsp.cert)
    tsp.valid_from = cert_obj.not_before
    tsp.valid_to = cert_obj.not_after
    tsp.name = CommonUi::CertUtils.cert_subject_cn(cert_obj)

    unless MaxlengthValidator.string_length_valid?(tsp.name)
      raise I18n.t("errors.tsp.cert_too_long_subject_name", {
          :max_length => Validators::STRING_MAX_LENGTH,
          :subject_name => tsp.name})
    end

    logger.info("Saving CA: '#{tsp}'")
  end

  before_update do |tsp|
    if tsp.cert_changed?
      tsp.errors[:cert] << "could not be modified for existing TSP"
      raise ActiveRecord::RecordInvalid.new(tsp)
    end
  end

  def to_s
    "ApprovedTsa(name: '#{self.name}', url: '#{self.url}', "\
        "validFrom: '#{self.valid_from}', validTo: '#{self.valid_to}')"
  end

  def self.get_approved_tsas(query_params)
    logger.info("get_approved_tsas(#{query_params})")

    get_search_relation(query_params.search_string).
        order("#{query_params.sort_column} #{query_params.sort_direction}").
        limit(query_params.display_length).
        offset(query_params.display_start)
  end

  def self.get_approved_tsa_count(searchable)
    logger.info("get_approved_tsa_count(#{searchable})")

    get_search_relation(searchable).count
  end

  private

  def self.get_search_relation(searchable)
    sql_generator =
        SimpleSearchSqlGenerator.new(get_searchable_columns, searchable)

    ApprovedTsa.
        where(sql_generator.sql, *sql_generator.params)
  end

  def self.get_searchable_columns
    [   "approved_tsas.name",
        "approved_tsas.valid_from",
        "approved_tsas.valid_to"
    ]
  end
end