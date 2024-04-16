module Notifier

using TOML
using Telegram, Telegram.API

export notify

config = TOML.parsefile("config.toml")
tg = TelegramClient(config["bot_token"]; chat_id=config["chat_id"])

function notify(message::AbstractString)
    sendMessage(text = message)
end

end
