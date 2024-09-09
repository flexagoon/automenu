module Config

using Configurations

@option struct Nutrition
    blacklist::Vector{String}
    calories_range::Vector{Int}
    min_protein::Int
end

@option struct Notifier
    bot_token::String
    chat_id::String
end

@option struct AutoMenu
    nutrition::Nutrition
    notifier::Notifier
end

load(filename::String) = from_toml(AutoMenu, filename)

end
